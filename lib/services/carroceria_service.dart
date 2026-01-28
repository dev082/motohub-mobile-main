import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/carroceria.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Service for managing trailer data
class CarroceriaService {
  /// Get all trailers for a motorista
  Future<List<Carroceria>> getCarroceriasByMotorista(String motoristaId) async {
    try {
      final response = await SupabaseConfig.client
          .from('carrocerias')
          .select()
          .eq('motorista_id', motoristaId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Carroceria.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get carrocerias by motorista error: $e');
      return [];
    }
  }

  /// Get a single trailer by ID
  Future<Carroceria?> getCarroceriaById(String carroceriaId) async {
    try {
      final response = await SupabaseConfig.client
          .from('carrocerias')
          .select()
          .eq('id', carroceriaId)
          .maybeSingle();

      if (response == null) return null;
      return Carroceria.fromJson(response);
    } catch (e) {
      debugPrint('Get carroceria by id error: $e');
      return null;
    }
  }

  /// Create a new trailer
  Future<Carroceria?> createCarroceria(Map<String, dynamic> data) async {
    try {
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await SupabaseConfig.client
          .from('carrocerias')
          .insert(data)
          .select()
          .single();

      return Carroceria.fromJson(response);
    } catch (e) {
      debugPrint('Create carroceria error: $e');
      return null;
    }
  }

  /// Update an existing trailer
  Future<Carroceria?> updateCarroceria(String carroceriaId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await SupabaseConfig.client
          .from('carrocerias')
          .update(updates)
          .eq('id', carroceriaId)
          .select()
          .single();

      return Carroceria.fromJson(response);
    } catch (e) {
      debugPrint('Update carroceria error: $e');
      return null;
    }
  }

  /// Delete a trailer
  Future<bool> deleteCarroceria(String carroceriaId) async {
    try {
      await SupabaseConfig.client.from('carrocerias').delete().eq('id', carroceriaId);
      return true;
    } catch (e) {
      debugPrint('Delete carroceria error: $e');
      return false;
    }
  }

  /// Soft delete (set ativo = false)
  Future<bool> deactivateCarroceria(String carroceriaId) async {
    try {
      await SupabaseConfig.client
          .from('carrocerias')
          .update({
            'ativo': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', carroceriaId);
      return true;
    } catch (e) {
      debugPrint('Deactivate carroceria error: $e');
      return false;
    }
  }
}
