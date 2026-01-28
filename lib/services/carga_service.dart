import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/carga.dart';
import 'package:hubfrete/models/motorista.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Service for managing cargas (freight loads)
class CargaService {
  /// Get available cargas for motorista
  /// Autônomos see all published cargas
  /// Frota drivers do not see any cargas (business rule)
  Future<List<Carga>> getAvailableCargas(Motorista motorista) async {
    try {
      debugPrint('Loading cargas for motorista: ${motorista.nomeCompleto}');
      debugPrint('Motorista type: ${motorista.isAutonomo ? "Autônomo" : "Frota"} (empresaId: ${motorista.empresaId})');

      // Business rule: frota drivers cannot explore cargas.
      if (motorista.isFrota) {
        debugPrint('Motorista de frota - explorar cargas desabilitado. Returning empty list.');
        return [];
      }

      var query = SupabaseConfig.client
          .from('cargas')
          .select('''
            *,
            origem:enderecos_carga!cargas_endereco_origem_id_fkey(*),
            destino:enderecos_carga!cargas_endereco_destino_id_fkey(*)
          ''')
          .inFilter('status', ['publicada', 'parcialmente_alocada']);

      debugPrint('Motorista autônomo - showing all available cargas');

      final data = await query.order('created_at', ascending: false);
      final cargas = (data as List).map((json) => Carga.fromJson(json)).toList();
      debugPrint('Loaded ${cargas.length} cargas from Supabase (filtered by status)');

      // Diagnóstico: se vier 0, é comum ser divergência de valores do enum `status`.
      // Fazemos uma consulta leve só para logar quais status existem no banco.
      if (cargas.isEmpty) {
        try {
          var statusProbe = SupabaseConfig.client.from('cargas').select('status');
          final probe = await statusProbe.limit(25);
          final statuses = (probe as List)
              .map((e) => (e as Map<String, dynamic>)['status']?.toString())
              .whereType<String>()
              .toSet()
              .toList();
          debugPrint('CargaService probe statuses (up to 25 rows): $statuses');
        } catch (e) {
          debugPrint('CargaService status probe failed: $e');
        }
      }

      return cargas;
    } catch (e) {
      debugPrint('Get available cargas error: $e');
      rethrow;
    }
  }

  /// Get carga details by ID
  Future<Carga?> getCargaById(String cargaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('cargas')
          .select('''
            *,
            origem:enderecos_carga!cargas_endereco_origem_id_fkey(*),
            destino:enderecos_carga!cargas_endereco_destino_id_fkey(*)
          ''')
          .eq('id', cargaId)
          .maybeSingle();

      if (data == null) return null;
      return Carga.fromJson(data);
    } catch (e) {
      debugPrint('Get carga by ID error: $e');
      return null;
    }
  }

  /// Search cargas by filters
  Future<List<Carga>> searchCargas({
    Motorista? motorista,
    String? searchText,
    TipoCarga? tipo,
    String? cidadeOrigem,
    String? cidadeDestino,
    DateTime? dataColetaDe,
    DateTime? dataColetaAte,
  }) async {
    try {
      if (motorista != null && motorista.isFrota) {
        debugPrint('Search cargas: motorista de frota - explorar cargas desabilitado. Returning empty list.');
        return [];
      }

      var query = SupabaseConfig.client
          .from('cargas')
          .select('''
            *,
            origem:enderecos_carga!cargas_endereco_origem_id_fkey(*),
            destino:enderecos_carga!cargas_endereco_destino_id_fkey(*)
          ''')
          .inFilter('status', ['publicada', 'parcialmente_alocada']);

      // Apply filters
      if (tipo != null) {
        query = query.eq('tipo', tipo.value);
      }

      if (dataColetaDe != null) {
        query = query.gte('data_coleta_de', dataColetaDe.toIso8601String());
      }

      if (dataColetaAte != null) {
        query = query.lte('data_coleta_ate', dataColetaAte.toIso8601String());
      }

      final data = await query.order('created_at', ascending: false);
      var cargas = (data as List).map((json) => Carga.fromJson(json)).toList();

      // Filter by search text (client-side)
      if (searchText != null && searchText.isNotEmpty) {
        cargas = cargas.where((c) =>
            c.codigo.toLowerCase().contains(searchText.toLowerCase()) ||
            c.descricao.toLowerCase().contains(searchText.toLowerCase())).toList();
      }

      // Filter by city (client-side)
      if (cidadeOrigem != null && cidadeOrigem.isNotEmpty) {
        cargas = cargas.where((c) =>
            c.origem?.cidade.toLowerCase().contains(cidadeOrigem.toLowerCase()) ?? false).toList();
      }

      if (cidadeDestino != null && cidadeDestino.isNotEmpty) {
        cargas = cargas.where((c) =>
            c.destino?.cidade.toLowerCase().contains(cidadeDestino.toLowerCase()) ?? false).toList();
      }

      return cargas;
    } catch (e) {
      debugPrint('Search cargas error: $e');
      rethrow;
    }
  }
}
