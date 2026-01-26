import 'package:flutter/foundation.dart';
import 'package:motohub/models/veiculo.dart';
import 'package:motohub/supabase/supabase_config.dart';

/// Service for managing vehicle data
class VeiculoService {
  /// Get all vehicles for a motorista
  Future<List<Veiculo>> getVeiculosByMotorista(String motoristaId) async {
    try {
      final response = await SupabaseConfig.client
          .from('veiculos')
          .select()
          .eq('motorista_id', motoristaId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Veiculo.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get veiculos by motorista error: $e');
      return [];
    }
  }

  /// Get a single vehicle by ID
  Future<Veiculo?> getVeiculoById(String veiculoId) async {
    try {
      final response = await SupabaseConfig.client
          .from('veiculos')
          .select()
          .eq('id', veiculoId)
          .maybeSingle();

      if (response == null) return null;
      return Veiculo.fromJson(response);
    } catch (e) {
      debugPrint('Get veiculo by id error: $e');
      return null;
    }
  }

  /// Create a new vehicle
  Future<Veiculo?> createVeiculo(Map<String, dynamic> data) async {
    try {
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await SupabaseConfig.client
          .from('veiculos')
          .insert(data)
          .select()
          .single();

      return Veiculo.fromJson(response);
    } catch (e) {
      debugPrint('Create veiculo error: $e');
      return null;
    }
  }

  /// Update an existing vehicle
  Future<Veiculo?> updateVeiculo(String veiculoId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await SupabaseConfig.client
          .from('veiculos')
          .update(updates)
          .eq('id', veiculoId)
          .select()
          .single();

      return Veiculo.fromJson(response);
    } catch (e) {
      debugPrint('Update veiculo error: $e');
      return null;
    }
  }

  /// Delete a vehicle
  Future<bool> deleteVeiculo(String veiculoId) async {
    try {
      await SupabaseConfig.client.from('veiculos').delete().eq('id', veiculoId);
      return true;
    } catch (e) {
      debugPrint('Delete veiculo error: $e');
      return false;
    }
  }

  /// Soft delete (set ativo = false)
  Future<bool> deactivateVeiculo(String veiculoId) async {
    try {
      await SupabaseConfig.client
          .from('veiculos')
          .update({
            'ativo': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', veiculoId);
      return true;
    } catch (e) {
      debugPrint('Deactivate veiculo error: $e');
      return false;
    }
  }
}
