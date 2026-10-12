# Roadmap

## v0.3.0 — implementação e build
- Captura AVFoundation Objective-C, iOS 9 / ARMv7.
- Full Android principal e Lite alternativa, scripts ES5.
- Estado/capacidades reais; alternar câmera, zoom, toque para foco, torch, presets/FPS anunciados e tela preta.
- MJPEG HD/SD separado, snapshot, limites de clientes, tratamento de envio parcial e desconexão, reinício do listener Darwin.
- Testes web locais e testes do servidor HTTP de produção no runner macOS.

## Validação pendente em dispositivo
- Safari iOS 9 e comportamento da câmera em iPad mini 1.
- Instalação e funcionamento da IPA pelo caminho legado/jailbreak.
- Medir estabilidade contínua, bateria, temperatura, resolução/FPS e latência do foco.

## Não implementado
- Áudio/microfone e sincronização com OBS.
- NDI: buscar SDK legalmente distribuível ARMv7/iOS 9; não usar SDK v6.
- Gravação, RTMP, WebRTC, Studio, GPU e foco/exposição manuais.
- Autenticação HTTP e operação em background.

Ver auditoria em [V0.3.0.md](V0.3.0.md). Não redistribuir frameworks proprietários de outros aplicativos.
