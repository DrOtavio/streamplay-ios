# StreamPlay v4.4 — correção OSStatus -50

## Causa confirmada no código
`setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])`
usa uma opção que só pode ser configurada explicitamente com `.playAndRecord`.
A chamada gera erro de parâmetro e o aplicativo retorna antes de criar o AVPlayerItem.

## Correção
`setCategory(.playback, mode: .moviePlayback, options: [])`

AirPlay segue suportado implicitamente pela categoria `.playback`.

## Teste
Instalar novo IPA, desconectar CarPlay e testar MP4 de teste, Apple HLS
e canal de lista M3U. Se a sessão de áudio funcionar mas a lista falhar,
verificar erro do player/URL/codec.

## Nota
Não há comprovação de compilação iOS neste ambiente, somente os testes
locais. Gere o IPA no GitHub Actions.
