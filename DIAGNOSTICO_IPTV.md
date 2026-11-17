# StreamPlay v4.3 — teste orientado de vídeo no iPhone

1. Desconecte o CarPlay. Em **Assistir**, teste primeiro **MP4 de teste**, depois **Apple HLS** e **Mux HLS**.
2. Se todos falharem, copie **Diagnóstico do player** e envie os erros reais do AVPlayer. A lista M3U não é a causa desse teste.
3. Se os três vídeos públicos funcionarem e apenas os canais da lista falharem, o problema costuma estar na URL do stream, formato/container, autorização (HTTP 401/403), limites de conexão, cabeçalhos de origem ou codec. O parser preserva nomes/logos, mas isso não autentica os streams.
4. **AVPlayer não substitui VLC/FFmpeg** e não reproduz qualquer link IPTV. Fluxos MPEG-TS diretos, alguns codecs e listas com EXTVLCOPT precisam de um motor adequado e tratamento explícito de cabeçalhos. Esta atualização é diagnóstico, não um fallback VLC implementado.
5. Não publique URL completa, tokens ou credenciais IPTV: o diagnóstico copia apenas host, protocolo, extensão e eventos do player.
6. A propriedade `usesExternalPlaybackWhileExternalScreenIsActive` foi redefinida para `false` para o teste local no iPhone.

**Verificações locais:** sintaxe Swift e consistência estrutural. A compilação real exige `xcodebuild` no macOS/GitHub Actions.
