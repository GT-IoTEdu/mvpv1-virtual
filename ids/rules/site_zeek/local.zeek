# Configuração básica do Zeek
@load base/protocols/conn
@load base/protocols/dns
@load base/protocols/http
@load base/frameworks/notice

# Resolve problema onde Zeek descarta pacotes com checksums incorretos
redef ignore_checksums = T;

# Carrega padrões de mensagens (mantém funções mas usa JSON output)
@load ./simir-notice-standards.zeek

# Carrega detectores personalizados
# Use @load ./intel-debug.zeek para modo diagnóstico simplificado
@load ./port-scan-detector.zeek
@load ./brute-force-detector.zeek
@load ./intelligence-framework.zeek
@load ./ddos-detector.zeek
@load ./data-exfiltration-detector.zeek
@load ./dns-tunneling-detector.zeek
@load ./lateral-movement-detector.zeek
@load ./sql-injection-detector.zeek
@load ./beaconing-detector.zeek
@load ./protocol-anomaly-detector.zeek
@load ./icmp-tunnel-detector.zeek

# Configurações de logging
# Habilita formato JSON para compatibilidade e comparação
redef LogAscii::use_json = T;

# Em hosts compartilhados (network_mode: host com outras instâncias Zeek
# rodando), defina ZEEK_DISABLE_METRICS=1 para evitar bind-conflict na
# porta padrão 9991 do endpoint Prometheus.
@if ( getenv("ZEEK_DISABLE_METRICS") == "1" )
redef Telemetry::metrics_port = 0/tcp;
@endif

# Configuração para garantir que todos os notices sejam logados
hook Notice::policy(n: Notice::Info) &priority=10
{
    # Força log para todos os notices
    add n$actions[Notice::ACTION_LOG];
}
