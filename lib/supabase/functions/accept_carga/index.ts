// supabase/functions/accept_carga/index.ts
// Accept a carga automatically: creates an entrega and debits vehicle capacity + carga remaining weight.

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type AcceptCargaBody = {
  carga_id: string;
  veiculo_id: string;
  carroceria_id?: string | null;
  peso_kg: number;
};

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse(405, { error: "method_not_allowed" });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return jsonResponse(500, { error: "missing_supabase_env" });
    }

    const authHeader = req.headers.get("Authorization") ?? "";

    // Admin client to perform transactional SQL safely regardless of RLS.
    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    // Identify requester.
    const { data: userData, error: userError } = await admin.auth.getUser(authHeader.replace("Bearer ", ""));
    if (userError || !userData?.user) {
      return jsonResponse(401, { error: "unauthorized" });
    }
    const authUid = userData.user.id;

    const body = (await req.json()) as Partial<AcceptCargaBody>;
    const cargaId = body.carga_id;
    const veiculoId = body.veiculo_id;
    const carroceriaId = body.carroceria_id ?? null;
    const pesoKg = typeof body.peso_kg === "number" ? body.peso_kg : NaN;

    if (!cargaId || !veiculoId || !Number.isFinite(pesoKg) || pesoKg <= 0) {
      return jsonResponse(400, { error: "invalid_payload" });
    }

    // 1) Load motorista for this auth user.
    const { data: motorista, error: motoristaError } = await admin
      .from("motoristas")
      .select("id, tipo_cadastro")
      .eq("user_id", authUid)
      .maybeSingle();

    if (motoristaError) return jsonResponse(500, { error: "motorista_query_failed", details: motoristaError.message });
    if (!motorista) return jsonResponse(403, { error: "motorista_not_found" });
    if (motorista.tipo_cadastro !== "autonomo") {
      return jsonResponse(403, { error: "only_autonomo_can_accept" });
    }

    // 2) Validate vehicle belongs to motorista.
    const { data: veiculo, error: veiculoError } = await admin
      .from("veiculos")
      .select("id, motorista_id, carroceria_integrada, carroceria_id")
      .eq("id", veiculoId)
      .maybeSingle();

    if (veiculoError) return jsonResponse(500, { error: "veiculo_query_failed", details: veiculoError.message });
    if (!veiculo) return jsonResponse(404, { error: "veiculo_not_found" });
    if (veiculo.motorista_id !== motorista.id) {
      return jsonResponse(403, { error: "veiculo_not_owned" });
    }

    // 3) Resolve carroceria efetiva (capacidade vem SEMPRE da carroceria).
    // - Se o veículo tiver carroceria integrada, usamos veiculo.carroceria_id
    // - Caso contrário, usamos a carroceria escolhida no payload
    const isIntegrada = veiculo.carroceria_integrada === true;
    const effectiveCarroceriaId = isIntegrada ? (veiculo.carroceria_id ?? null) : carroceriaId;
    if (!effectiveCarroceriaId) {
      return jsonResponse(400, { error: "carroceria_required" });
    }

    const { data: carroceria, error: carroceriaError } = await admin
      .from("carrocerias")
      .select("id, motorista_id, capacidade_kg")
      .eq("id", effectiveCarroceriaId)
      .maybeSingle();
    if (carroceriaError) return jsonResponse(500, { error: "carroceria_query_failed", details: carroceriaError.message });
    if (!carroceria) return jsonResponse(404, { error: "carroceria_not_found" });
    if (carroceria.motorista_id !== motorista.id) {
      return jsonResponse(403, { error: "carroceria_not_owned" });
    }
    if (carroceria.capacidade_kg == null) {
      return jsonResponse(400, { error: "carroceria_missing_capacidade_kg" });
    }
    if (pesoKg > carroceria.capacidade_kg) {
      return jsonResponse(400, { error: "peso_exceeds_carroceria_capacity", available_kg: carroceria.capacidade_kg });
    }

    // 4) Load carga and check availability.
    const { data: carga, error: cargaError } = await admin
      .from("cargas")
      .select("id, codigo, status, peso_kg, peso_disponivel_kg, permite_fracionado")
      .eq("id", cargaId)
      .maybeSingle();

    if (cargaError) return jsonResponse(500, { error: "carga_query_failed", details: cargaError.message });
    if (!carga) return jsonResponse(404, { error: "carga_not_found" });

    if (!(carga.status === "publicada" || carga.status === "parcialmente_alocada")) {
      return jsonResponse(400, { error: "carga_not_available", status: carga.status });
    }

    if (carga.permite_fracionado === false && pesoKg !== carga.peso_kg) {
      return jsonResponse(400, { error: "carga_not_fracionada", required_kg: carga.peso_kg });
    }

    const pesoDisponivel = (carga.peso_disponivel_kg ?? carga.peso_kg) as number;
    if (pesoKg > pesoDisponivel) {
      return jsonResponse(400, { error: "peso_exceeds_carga_available", available_kg: pesoDisponivel });
    }

    // 5) Use a single SQL transaction to:
    // - insert entrega
    // - update veiculo capacidade_kg
    // - update carga peso_disponivel_kg + status
    // We rely on a Postgres function (RPC) created in a migration (see repo).
    const { data: rpcData, error: rpcError } = await admin.rpc("accept_carga_tx", {
      p_motorista_id: motorista.id,
      p_carga_id: cargaId,
      p_veiculo_id: veiculoId,
      p_carroceria_id: effectiveCarroceriaId,
      p_peso_kg: pesoKg,
    });

    if (rpcError) {
      return jsonResponse(400, { error: "accept_failed", details: rpcError.message });
    }

    return jsonResponse(200, { entrega: rpcData });
  } catch (e) {
    return jsonResponse(500, { error: "unexpected_error", details: String(e) });
  }
});
