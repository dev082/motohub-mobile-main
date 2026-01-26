import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-max-age': '86400',
}

// Run this function every 30 seconds via cron or manual trigger
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get active tracking sessions
    const { data: sessions, error: sessionsError } = await supabase
      .from('tracking_sessions')
      .select(`
        id,
        entrega_id,
        motorista_id,
        started_at,
        total_distance_km,
        average_speed_kmh,
        last_location_at,
        entregas:entrega_id (
          id,
          status,
          carga:carga_id (
            endereco_destino:endereco_destino_id (
              latitude,
              longitude
            )
          )
        )
      `)
      .eq('status', 'active')

    if (sessionsError) throw sessionsError
    if (!sessions || sessions.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No active sessions' }),
        { status: 200, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      )
    }

    const notifications = []

    for (const session of sessions) {
      // Get latest location
      const { data: latestLoc } = await supabase
        .from('locations')
        .select('*')
        .eq('entrega_id', session.entrega_id)
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

      if (!latestLoc) continue

      const entrega = session.entregas as any
      const destino = entrega?.carga?.endereco_destino

      if (!destino || !destino.latitude || !destino.longitude) continue

      // Calculate distance to destination (Haversine)
      const R = 6371
      const dLat = (destino.latitude - latestLoc.latitude) * Math.PI / 180
      const dLon = (destino.longitude - latestLoc.longitude) * Math.PI / 180
      const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(latestLoc.latitude * Math.PI / 180) * 
                Math.cos(destino.latitude * Math.PI / 180) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2)
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      const distanceKm = R * c

      // Calculate ETA based on average speed
      let etaMinutes = null
      if (session.average_speed_kmh && session.average_speed_kmh > 0) {
        etaMinutes = Math.round((distanceKm / session.average_speed_kmh) * 60)
      }

      // Check if near destination (< 500m)
      if (distanceKm < 0.5) {
        // Check if we already sent this notification recently
        const { data: recentNotif } = await supabase
          .from('notifications_log')
          .select('id')
          .eq('entrega_id', session.entrega_id)
          .eq('tipo', 'chegada_destino')
          .gte('enviada_em', new Date(Date.now() - 5 * 60 * 1000).toISOString()) // Last 5 min
          .limit(1)

        if (!recentNotif || recentNotif.length === 0) {
          notifications.push({
            entrega_id: session.entrega_id,
            motorista_id: session.motorista_id,
            tipo: 'chegada_destino',
            titulo: '🏁 Chegando ao Destino',
            mensagem: `Você está a ${(distanceKm * 1000).toFixed(0)}m do destino`,
            dados: { distance_m: Math.round(distanceKm * 1000) }
          })
        }
      }
      // ETA notification (arriving in 5-15 minutes)
      else if (etaMinutes && etaMinutes >= 5 && etaMinutes <= 15) {
        const { data: recentEta } = await supabase
          .from('notifications_log')
          .select('id')
          .eq('entrega_id', session.entrega_id)
          .eq('tipo', 'eta_update')
          .gte('enviada_em', new Date(Date.now() - 10 * 60 * 1000).toISOString())
          .limit(1)

        if (!recentEta || recentEta.length === 0) {
          notifications.push({
            entrega_id: session.entrega_id,
            motorista_id: session.motorista_id,
            tipo: 'eta_update',
            titulo: '⏱️ Previsão de Chegada',
            mensagem: `Você deve chegar em aproximadamente ${etaMinutes} minutos`,
            dados: { eta_minutes: etaMinutes, distance_km: distanceKm.toFixed(2) }
          })
        }
      }

      // Check for offline driver (no location update in 10 minutes)
      const lastUpdateMs = new Date(latestLoc.created_at).getTime()
      const nowMs = Date.now()
      if (nowMs - lastUpdateMs > 10 * 60 * 1000) {
        const { data: recentOffline } = await supabase
          .from('notifications_log')
          .select('id')
          .eq('entrega_id', session.entrega_id)
          .eq('tipo', 'offline')
          .gte('enviada_em', new Date(nowMs - 15 * 60 * 1000).toISOString())
          .limit(1)

        if (!recentOffline || recentOffline.length === 0) {
          notifications.push({
            entrega_id: session.entrega_id,
            motorista_id: session.motorista_id,
            tipo: 'offline',
            titulo: '📶 Motorista Offline',
            mensagem: 'Sem atualizações de localização há mais de 10 minutos',
            dados: { last_update: latestLoc.created_at }
          })
        }
      }
    }

    // Insert notifications
    if (notifications.length > 0) {
      const { error: insertError } = await supabase
        .from('notifications_log')
        .insert(notifications)

      if (insertError) {
        console.error('Insert notifications error:', insertError)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sessions_checked: sessions.length,
        notifications_sent: notifications.length,
      }),
      { status: 200, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
    )
  } catch (error) {
    console.error('Check trip events error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
    )
  }
})
