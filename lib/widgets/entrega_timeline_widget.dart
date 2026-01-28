import 'package:flutter/material.dart';
import 'package:hubfrete/models/entrega_evento.dart';
import 'package:intl/intl.dart';

/// Widget de timeline para exibir eventos de uma entrega
class EntregaTimelineWidget extends StatelessWidget {
  final List<EntregaEvento> eventos;

  const EntregaTimelineWidget({super.key, required this.eventos});

  @override
  Widget build(BuildContext context) {
    if (eventos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum evento registrado', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final evento = eventos[index];
        final isLast = index == eventos.length - 1;
        return _TimelineItem(evento: evento, isLast: isLast);
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final EntregaEvento evento;
  final bool isLast;

  const _TimelineItem({required this.evento, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getEventoColor(evento.tipo).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _getEventoColor(evento.tipo), width: 2),
                ),
                child: Icon(_getEventoIcon(evento.tipo), size: 20, color: _getEventoColor(evento.tipo)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Event content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(evento.tipo.displayName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(evento.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  if (evento.observacao != null && evento.observacao!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(evento.observacao!, style: theme.textTheme.bodyMedium),
                  ],
                  if (evento.userNome != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(evento.userNome!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ],
                  if (evento.latitude != null && evento.longitude != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${evento.latitude!.toStringAsFixed(4)}, ${evento.longitude!.toStringAsFixed(4)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                  if (evento.fotoUrl != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(evento.fotoUrl!, height: 120, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventoIcon(TipoEventoEntrega tipo) {
    switch (tipo) {
      case TipoEventoEntrega.aceite:
        return Icons.check_circle;
      case TipoEventoEntrega.inicioColeta:
        return Icons.play_arrow;
      case TipoEventoEntrega.chegadaColeta:
        return Icons.location_on;
      case TipoEventoEntrega.carregou:
        return Icons.inventory;
      case TipoEventoEntrega.inicioRota:
        return Icons.directions;
      case TipoEventoEntrega.parada:
        return Icons.pause;
      case TipoEventoEntrega.chegadaDestino:
        return Icons.flag;
      case TipoEventoEntrega.descarregou:
        return Icons.unarchive;
      case TipoEventoEntrega.finalizado:
        return Icons.done_all;
      case TipoEventoEntrega.problema:
        return Icons.error;
      case TipoEventoEntrega.cancelado:
        return Icons.cancel;
      case TipoEventoEntrega.desvioRota:
        return Icons.warning;
      case TipoEventoEntrega.paradaProlongada:
        return Icons.watch_later;
      case TipoEventoEntrega.velocidadeAnormal:
        return Icons.speed;
      case TipoEventoEntrega.perdaSinal:
        return Icons.signal_wifi_off;
      case TipoEventoEntrega.recuperacaoSinal:
        return Icons.signal_wifi_4_bar;
      case TipoEventoEntrega.entradaGeofence:
        return Icons.login;
      case TipoEventoEntrega.saidaGeofence:
        return Icons.logout;
    }
  }

  Color _getEventoColor(TipoEventoEntrega tipo) {
    switch (tipo) {
      case TipoEventoEntrega.aceite:
      case TipoEventoEntrega.finalizado:
        return Colors.green;
      case TipoEventoEntrega.problema:
      case TipoEventoEntrega.cancelado:
      case TipoEventoEntrega.desvioRota:
      case TipoEventoEntrega.perdaSinal:
        return Colors.red;
      case TipoEventoEntrega.paradaProlongada:
      case TipoEventoEntrega.velocidadeAnormal:
        return Colors.orange;
      case TipoEventoEntrega.inicioColeta:
      case TipoEventoEntrega.inicioRota:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
