import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-max-age': '86400',
}

// Rate limiting: 30 updates per minute per driver
const RATE_LIMIT_WINDOW_MS = 60 * 1000 // 1 minute
const MAX_UPDATES_PER_WINDOW = 30
const rateLimit = new Map<string, { count: number; resetAt: number }>()

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { location } = await req.json()

    // Validate required fields
    if (!location || !location.entrega_id || !location.motorista_id || 
        location.latitude == null || location.longitude == null) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      )
    }

    // Apply rate limiting
    const driverId = location.motorista_id
    const now = Date.now()
    const limit = rateLimit.get(driverId)

    if (limit) {
      if (now < limit.resetAt) {
        if (limit.count >= MAX_UPDATES_PER_WINDOW) {
          return new Response(
            JSON.stringify({ error: 'Rate limit exceeded. Please slow down.' }),
            { status: 429, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
          )
        }
        limit.count++
      } else {
        rateLimit.set(driverId, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS })
      }
    } else {
      rateLimit.set(driverId, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS })
    }

    // Validate accuracy (discard if > 50m)
    if (location.accuracy && location.accuracy > 50) {
      console.log(`Discarding location with poor accuracy: ${location.accuracy}m`)
      return new Response(
        JSON.stringify({ message: 'Location accuracy too low', accuracy: location.accuracy }),
        { status: 400, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      )
    }

    // Calculate speed if previous location exists
    const { data: prevLocation } = await supabase
      .from('locations')
      .select('latitude, longitude, created_at')
      .eq('entrega_id', location.entrega_id)
      .order('created_at', { ascending: false })
      .limit(1)
      .single()

    let calculatedSpeed = location.speed || 0
    let distance = 0

    if (prevLocation) {
      // Haversine distance
      const R = 6371 // Earth radius in km
      const dLat = (location.latitude - prevLocation.latitude) * Math.PI / 180
      const dLon = (location.longitude - prevLocation.longitude) * Math.PI / 180
      const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(prevLocation.latitude * Math.PI / 180) * 
                Math.cos(location.latitude * Math.PI / 180) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2)
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      distance = R * c // km

      const timeDiff = (Date.now() - new Date(prevLocation.created_at).getTime()) / 1000 // seconds
      if (timeDiff > 0) {
        calculatedSpeed = (distance / timeDiff) * 3600 // km/h
      }
    }

    // Insert location
    const { data: inserted, error } = await supabase
      .from('locations')
      .insert({
        entrega_id: location.entrega_id,
        motorista_id: location.motorista_id,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        speed: calculatedSpeed,
        heading: location.heading,
        altitude: location.altitude,
        battery_level: location.battery_level,
        is_moving: location.is_moving ?? (calculatedSpeed > 5),
      })
      .select()
      .single()

    if (error) {
      console.error('Insert location error:', error)
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      )
    }

    // Check for events (low battery, near destination, etc.)
    const events = []

    if (location.battery_level && location.battery_level < 20) {
      events.push({ type: 'low_battery', level: location.battery_level })
    }

    if (distance > 0 && distance < 0.5) { // < 500m
      events.push({ type: 'near_destination', distance_km: distance })
    }

    return new Response(
      JSON.stringify({
        success: true,
        location: inserted,
        events,
        metrics: {
          distance_km: distance.toFixed(3),
          speed_kmh: calculatedSpeed.toFixed(1),
        }
      }),
      { status: 200, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
    )
  } catch (error) {
    console.error('Process location error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
    )
  }
})
