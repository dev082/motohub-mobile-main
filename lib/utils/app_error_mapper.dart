import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/app_user_alert.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppErrorMapper {
  static AppUserAlert fromError(Object error, {String? operation}) {
    final now = DateTime.now();
    final raw = _toSafeString(error);
    final op = (operation == null || operation.trim().isEmpty) ? null : operation.trim();

    // Supabase specific
    if (error is AuthException) {
      return AppUserAlert(
        id: _id(now),
        severity: AppUserAlertSeverity.warning,
        code: 'AUTH_SESSION',
        title: 'Sessão precisa de atenção',
        message: op == null
            ? 'Sua sessão pode ter expirado. Para continuar, faça login novamente.'
            : 'Não foi possível $op. Sua sessão pode ter expirado.',
        steps: const [
          'Toque em “Entrar de novo”.',
          'Faça login com seu e-mail e senha.',
          'Tente novamente a ação anterior.',
        ],
        actionLabel: 'Entrar de novo',
        action: AppUserAlertAction.relogin,
        technicalDetails: raw,
        createdAt: now,
      );
    }

    if (error is PostgrestException) {
      final status = error.code?.trim();
      // PostgREST uses various codes; permissions often come as 401/403 or postgres codes.
      if (_looksLikeUnauthorized(raw) || status == '401') {
        return AppUserAlert(
          id: _id(now),
          severity: AppUserAlertSeverity.warning,
          code: 'AUTH_UNAUTHORIZED',
          title: 'Acesso não autorizado',
          message: op == null
              ? 'Seu acesso não foi autorizado. Pode ser sessão expirada.'
              : 'Não foi possível $op porque seu acesso não foi autorizado.',
          steps: const [
            'Toque em “Entrar de novo”.',
            'Se o problema continuar, avise o suporte com o código do erro.',
          ],
          actionLabel: 'Entrar de novo',
          action: AppUserAlertAction.relogin,
          technicalDetails: raw,
          createdAt: now,
        );
      }

      if (_looksLikeForbidden(raw) || status == '403') {
        return AppUserAlert(
          id: _id(now),
          severity: AppUserAlertSeverity.error,
          code: 'PERMISSION_DENIED',
          title: 'Sem permissão para acessar dados',
          message: op == null
              ? 'Você não tem permissão para acessar esses dados. Isso geralmente é configuração do sistema.'
              : 'Não foi possível $op por falta de permissão.',
          steps: const [
            'Confirme se você está usando o usuário correto.',
            'Se persistir, envie o código do erro ao suporte.',
          ],
          actionLabel: 'Como resolver',
          action: AppUserAlertAction.showFixSteps,
          technicalDetails: raw,
          createdAt: now,
        );
      }
    }

    // Timeouts / network
    if (error is TimeoutException || _looksLikeTimeout(raw)) {
      return _networkAlert(
        now,
        code: 'NETWORK_TIMEOUT',
        title: 'Conexão lenta',
        message: op == null
            ? 'Sua conexão está lenta e a solicitação expirou.'
            : 'Não foi possível $op porque a conexão expirou.',
        technicalDetails: raw,
      );
    }

    if (_looksLikeNetworkDrop(raw)) {
      return _networkAlert(
        now,
        code: 'NETWORK_DROPPED',
        title: 'Conexão instável',
        message: op == null
            ? 'A conexão caiu antes de concluir a resposta do servidor.'
            : 'Não foi possível $op porque a conexão caiu.',
        technicalDetails: raw,
      );
    }

    if (_looksLikeHostLookup(raw)) {
      return _networkAlert(
        now,
        code: 'NETWORK_DNS',
        title: 'Sem internet',
        message: op == null
            ? 'Não conseguimos acessar a internet agora.'
            : 'Não foi possível $op porque parece que você está sem internet.',
        technicalDetails: raw,
      );
    }

    // Fallback
    return AppUserAlert(
      id: _id(now),
      severity: AppUserAlertSeverity.error,
      code: 'UNKNOWN_ERROR',
      title: 'Algo deu errado',
      message: op == null
          ? 'Ocorreu um erro inesperado. Tente novamente.'
          : 'Não foi possível $op. Tente novamente.',
      steps: const [
        'Tente novamente em alguns instantes.',
        'Se continuar, avise o suporte com o código do erro.',
      ],
      actionLabel: 'Como resolver',
      action: AppUserAlertAction.showFixSteps,
      technicalDetails: raw,
      createdAt: now,
    );
  }

  static AppUserAlert _networkAlert(
    DateTime now, {
    required String code,
    required String title,
    required String message,
    required String technicalDetails,
  }) {
    return AppUserAlert(
      id: _id(now),
      severity: AppUserAlertSeverity.warning,
      code: code,
      title: title,
      message: message,
      steps: const [
        'Verifique se o celular está com internet (Wi‑Fi/4G/5G).',
        'Se estiver em Wi‑Fi, tente trocar para 4G/5G (ou vice‑versa).',
        'Aguarde alguns segundos e tente novamente.',
      ],
      actionLabel: 'Ver solução',
      action: AppUserAlertAction.showFixSteps,
      technicalDetails: technicalDetails,
      createdAt: now,
    );
  }

  static String _toSafeString(Object error) {
    try {
      return error.toString();
    } catch (_) {
      return 'Error';
    }
  }

  static String _id(DateTime now) => '${now.millisecondsSinceEpoch}-${now.microsecondsSinceEpoch.remainder(1000)}';

  static bool _looksLikeNetworkDrop(String raw) {
    final s = raw.toLowerCase();
    return s.contains('connection closed before full header was received') ||
        s.contains('connection reset by peer') ||
        s.contains('broken pipe') ||
        s.contains('connection terminated') ||
        s.contains('socketexception');
  }

  static bool _looksLikeHostLookup(String raw) {
    final s = raw.toLowerCase();
    return s.contains('failed host lookup') || s.contains('name not resolved') || s.contains('dns');
  }

  static bool _looksLikeTimeout(String raw) {
    final s = raw.toLowerCase();
    return s.contains('timed out') || s.contains('timeout');
  }

  static bool _looksLikeUnauthorized(String raw) {
    final s = raw.toLowerCase();
    return s.contains('jwt') && (s.contains('expired') || s.contains('invalid')) || s.contains('401');
  }

  static bool _looksLikeForbidden(String raw) {
    final s = raw.toLowerCase();
    return s.contains('permission denied') || s.contains('rls') || s.contains('403');
  }
}
