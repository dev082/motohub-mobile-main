# 🚀 Setup do Sistema de Rastreamento em Tempo Real

Este documento contém as instruções para configurar o sistema completo de rastreamento em tempo real no seu projeto.

## ✅ Implementações Concluídas

### 1. **Flutter (App Mobile)**
- ✅ Models: `LocationPoint`, `TrackingSession`, `AppNotification`
- ✅ Services:
  - `CacheService`: Cache offline com Hive
  - `LocationTrackingService`: Rastreamento adaptativo com otimização de bateria
  - `NotificationService`: Notificações locais com múltiplos canais
- ✅ Integração automática: O rastreamento inicia quando o status muda para `emColeta` e para automaticamente ao finalizar
- ✅ Dependencies adicionadas: hive, hive_flutter, workmanager, battery_plus, connectivity_plus

### 2. **Edge Functions (Supabase)**
- ✅ `process-location`: Validação, rate limiting (30 updates/min), cálculo de métricas
- ✅ `check-trip-events`: Monitoramento a cada 30s para ETA, chegada, offline, etc.

### 3. **SQL Migrations**
- ✅ Migration criada em `supabase/migrations/20260124000001_realtime_tracking_tables.sql`

---

## 📋 Próximos Passos (VOCÊ DEVE EXECUTAR)

### **PASSO 1: Aplicar Migration no Supabase**

1. Abra o **painel Supabase** no menu lateral esquerdo
2. Clique em **"SQL Editor"** ou **"Migrations"**
3. Aplique a migration localizada em:
   ```
   supabase/migrations/20260124000001_realtime_tracking_tables.sql
   ```

Esta migration criará:
- ✅ Tabela `locations` (pontos de localização em tempo real)
- ✅ Tabela `tracking_sessions` (sessões de rastreamento com métricas)
- ✅ Tabela `devices` (dispositivos para notificações)
- ✅ Tabela `notifications_log` (histórico de notificações)
- ✅ RLS Policies (segurança em nível de linha)
- ✅ Realtime habilitado
- ✅ Triggers automáticos para cálculo de distância

---

### **PASSO 2: Deploy das Edge Functions**

No painel Supabase, vá em **"Edge Functions"** e faça o deploy de:

#### **2.1. process-location**
```
Local: lib/supabase/functions/process-location/index.ts
```
- **Descrição**: Valida e processa pontos de localização com rate limiting
- **verify_jwt**: ✅ Habilitado (requer autenticação)
- **Secrets**: Nenhum adicional necessário

#### **2.2. check-trip-events**
```
Local: lib/supabase/functions/check-trip-events/index.ts
```
- **Descrição**: Monitora viagens ativas e dispara notificações (ETA, chegada, offline)
- **verify_jwt**: ✅ Habilitado
- **Execução**: Recomendado configurar um **Cron Job** para rodar a cada 30 segundos
- **Secrets**: Nenhum adicional necessário

**Como configurar Cron no Supabase:**
1. Acesse **Database** > **Extensions**
2. Habilite a extensão **pg_cron**
3. Execute no SQL Editor:
```sql
-- Executar check-trip-events a cada 30 segundos
SELECT cron.schedule(
  'check-trip-events-every-30s',
  '*/30 * * * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://SEU_PROJETO_REF.supabase.co/functions/v1/check-trip-events',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.service_role_key') || '"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
```

---

## 🔧 Configurações de Permissões

### **Android (AndroidManifest.xml)**

Adicione as permissões no arquivo `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- Localização -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    
    <!-- Notificações -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <!-- Bateria -->
    <uses-permission android:name="android.permission.BATTERY_STATS" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    
    <!-- Internet -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- Foreground Service -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
</manifest>
```

### **iOS (Info.plist)**

Adicione as permissões no arquivo `ios/Runner/Info.plist`:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para rastrear suas entregas em tempo real</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para rastrear suas entregas</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Precisamos da sua localização em segundo plano para rastrear suas entregas</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
    <string>processing</string>
</array>
```

---

## 🎯 Como Funciona

### **Fluxo Automático de Rastreamento:**

1. **Motorista inicia a coleta** (muda status para `emColeta`)
   - ✅ O rastreamento é **automaticamente iniciado**
   - 📍 Localização enviada a cada **5 segundos** (em movimento) ou **30 segundos** (parado)
   - 🔋 Intervalo aumenta para **60 segundos** quando bateria < 20%
   - 💾 Dados salvos localmente (Hive) para sincronização offline

2. **Durante o transporte**
   - 🚚 Pontos de localização enviados ao Supabase
   - 📊 Métricas calculadas: velocidade, distância, ETA
   - 🔔 Notificações disparadas automaticamente:
     - "Chegando em 5 minutos" (quando ETA < 15min)
     - "Chegada ao destino" (quando < 500m)
     - "Motorista offline" (sem atualização há 10min)
     - "Bateria baixa" (< 15%)

3. **Finalização**
   - ✅ Quando status = `entregue`, `cancelada` ou `devolvida`
   - 🛑 O rastreamento é **automaticamente parado**
   - 📈 Sessão de tracking completada com estatísticas finais

---

## 📊 Otimizações Implementadas

### **Bateria:**
- ✅ Precisão reduzida (medium) quando bateria < 20%
- ✅ Intervalo adaptativo baseado em movimento
- ✅ GPS desligado quando parado por > 5 minutos

### **Dados:**
- ✅ Compressão: apenas campos alterados são enviados
- ✅ Batch updates quando offline
- ✅ Cache agressivo com Hive (até 100 localizacoes)

### **Conexão:**
- ✅ Reconexão automática com backoff exponencial
- ✅ Buffer offline para sincronização posterior
- ✅ Rate limiting: máximo 30 updates/minuto

---

## 🧪 Testando o Sistema

### **1. Teste Básico:**
1. Faça login no app como motorista
2. Selecione uma entrega ativa
3. Mude o status para **"Em Coleta"**
4. ✅ Você deve receber a notificação: "📦 Coleta Iniciada - Rastreamento ativo"
5. Verifique no Supabase se os pontos estão sendo salvos na tabela `locations`

### **2. Teste de Notificações:**
- Aguarde alguns minutos com o app em background
- Você deve receber notificações automáticas baseadas em eventos (ETA, chegada, etc.)

### **3. Teste Offline:**
1. Desative o Wi-Fi/dados móveis
2. Movimente-se com o app aberto
3. Reative a conexão
4. ✅ Os pontos offline devem ser sincronizados automaticamente

---

## 📚 Documentação das Tabelas

### **`locations`**
Armazena cada ponto de localização coletado em tempo real.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | UUID | ID único |
| entrega_id | UUID | Referência à entrega |
| motorista_id | UUID | Referência ao motorista |
| latitude | NUMERIC | Latitude (-90 a 90) |
| longitude | NUMERIC | Longitude (-180 a 180) |
| accuracy | NUMERIC | Precisão em metros |
| speed | NUMERIC | Velocidade em km/h |
| heading | NUMERIC | Direção em graus (0-360) |
| battery_level | INTEGER | Nível de bateria (0-100) |
| is_moving | BOOLEAN | Se está em movimento |
| created_at | TIMESTAMPTZ | Timestamp da coleta |

### **`tracking_sessions`**
Gerencia sessões de rastreamento com métricas agregadas.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | UUID | ID único |
| entrega_id | UUID | Referência à entrega |
| motorista_id | UUID | Referência ao motorista |
| status | TEXT | active, paused, completed, cancelled |
| total_distance_km | NUMERIC | Distância total percorrida |
| total_duration_seconds | INTEGER | Duração total em segundos |
| average_speed_kmh | NUMERIC | Velocidade média |
| max_speed_kmh | NUMERIC | Velocidade máxima |
| points_collected | INTEGER | Número de pontos coletados |
| last_location_at | TIMESTAMPTZ | Última atualização |
| started_at | TIMESTAMPTZ | Início da sessão |
| ended_at | TIMESTAMPTZ | Fim da sessão |

### **`notifications_log`**
Histórico de todas as notificações enviadas.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | UUID | ID único |
| entrega_id | UUID | Referência à entrega |
| motorista_id | UUID | Referência ao motorista |
| tipo | TEXT | Tipo da notificação (coleta_iniciada, eta_update, etc.) |
| titulo | TEXT | Título da notificação |
| mensagem | TEXT | Corpo da notificação |
| dados | JSONB | Dados adicionais |
| enviada_em | TIMESTAMPTZ | Timestamp de envio |
| lida | BOOLEAN | Se foi lida |

---

## ⚠️ Troubleshooting

### **Problema: Rastreamento não inicia**
- Verifique se as permissões de localização foram concedidas
- Confira se a migration foi aplicada corretamente
- Veja os logs no Debug Console: `mcp__hologram__get_app_logs`

### **Problema: localizacoes não aparecem no Supabase**
- Verifique se as Edge Functions foram deployed
- Confirme se o RLS está configurado corretamente
- Teste chamando a Edge Function `process-location` manualmente

### **Problema: Notificações não aparecem**
- Verifique se as permissões de notificação foram concedidas
- Confirme se os canais de notificação foram criados (Android)
- Veja se a Edge Function `check-trip-events` está rodando (Cron)

---

## 📞 Suporte

Caso encontre algum problema:
1. Verifique os logs do app: `mcp__hologram__get_app_logs`
2. Verifique os logs das Edge Functions no painel Supabase
3. Consulte a documentação do Supabase: https://supabase.com/docs

---

**✅ Sistema Pronto para Uso!**

Após aplicar a migration e fazer o deploy das Edge Functions, o rastreamento estará **totalmente funcional e automático**.
