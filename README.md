# StreamPlay 4 — Navegador + IPTV + CarPlay experimental

**Objetivo:** aplicativo iOS com UI original inspirada na organização do LeyTV (preto, acento lima, quatro abas, tela Carro, Browser e IPTV). Não contém código, ícones, logotipos nem outros arquivos do LeyTV. Requer iOS 17+ para o iPhone; fontes AVKit/WebKit/MapKit são nativas.

## O que funciona no iPhone

- **Carro:** painel de status de conexão, caminhos para Navegador, Mídia, Mapas, touchpad e instruções de espelhamento.
- **Navegador real:** `WKWebView`, sites por URL, pesquisa, múltiplas abas com WKWebViews separados, favoritos, histórico, atalhos e navegação voltar/avançar/recarregar. Sites podem bloquear vídeo/DRM dentro do WebKit.
- **IPTV real:** URL remota M3U/M3U8 ou arquivo M3U local, tags `#EXTINF`, `tvg-logo`, `group-title`, filtro, favoritos, persistência, `AVPlayer`/`VideoPlayer`, botões, AirPlay. URLs de demonstração (Apple/Mux) são explicitamente identificadas como testes; nenhum canal comercial é distribuído.
- **Mapas:** mapa MapKit interativo.
- **Touchpad:** deslocamento, clique, scroll e texto para campo selecionado na janela CarPlay **somente se esta realmente conectar**. Nem todo site aceita clique sintético/alteração programática de campos.

## O que NÃO é garantido no carro

O modo `CarDisplayWindowSceneDelegate` usa um role de `UIWindowScene` para CarPlay, de acordo com o exemplo aberto do Cafari Lite (licença MIT). O projeto não inclui nem falsifica entitlements gerenciados. **O sistema só cria essa cena se a assinatura e o veículo tiverem capacidades autorizadas.** A API oficial de vídeo CarPlay introduzida com iOS 27 também requer entitlement de vídeo e veículo compatível; os recursos disponíveis no iOS 26 são restritos.

O `CarPlaySceneDelegate` original permanece para **áudio via templates**, se autorizado com entitlement de áudio. Isso não torna o navegador e vídeo disponíveis no painel. Uma conta gratuita + Sideloadly **não recebe automaticamente** permissões CarPlay. O navegador touchpad funciona apenas em uma janela CarPlay com acesso efetivo; antes disso a UI mostra `AGUARDANDO CARRO`, sem simular conexão.

Use vídeo visual somente com o veículo estacionado, ou em telas destinadas a passageiros. Não tente contornar bloqueios do veículo.

## Estrutura

```
StreamPlay.xcodeproj/
StreamPlay/
  App.swift                 # roteamento da cena iPhone, template e janela CarPlay experimental
  ContentView.swift         # interface original neon-lima
  BrowserStore.swift        # tabs, WKWebView, histórico, favoritos
  ChannelService.swift      # parser real M3U/EXTINF
  ChannelViewModel.swift    # importação, AVPlayer, cache local
  CarDisplayCoordinator.swift
  CarDisplayWindowSceneDelegate.swift
  CarDisplayViewController.swift
  CarPlaySceneDelegate.swift
  Models.swift
  PlayerViewController.swift
  RemoteCommandController.swift
  SceneDelegate.swift
  Info.plist
  Assets.xcassets/
CarPlayEntitlements/         # exemplos condicionados à aprovação da Apple
scripts/build-unsigned-ipa.sh
.github/workflows/build-ipa.yml
gen_xcodeproj.py
```

## Gerar IPA no GitHub (sem Mac local)

1. No repositório `DrOtavio/streamplay-ios`, substitua os arquivos anteriores pelos deste pacote **mantendo a hierarquia**. A pasta `.github/workflows` precisa ser incluída. Não suba a pasta `.git`.
2. Entre em **Actions → Build StreamPlay 4 IPA → Run workflow**. O runner `xcode-27` executa `xcodebuild` em macOS com Xcode.
3. Se a execução ficar verde, baixe o artifact **StreamPlay-v4-IPA**, extraia `StreamPlay-unsigned.ipa` e assine com Sideloadly. O IPA assinado com Apple ID grátis funciona no iPhone, mas **não concede autorização de vídeo CarPlay**.
4. Se falhar, copie a primeira mensagem de erro na etapa `Build unsigned IPA`. Os arquivos Swift passaram por análise sintática local; **não foi possível fazer o typecheck/compilação iOS no Linux**.

### Gerar no macOS localmente

```bash
bash scripts/build-unsigned-ipa.sh
```

## Regenerar projeto via Python

```bash
python3 gen_xcodeproj.py --output ./OutroStreamPlay
python3 test_bootstrap.py
```

`gen_xcodeproj.py` guarda os arquivos do projeto em uma carga compactada e cria uma cópia idêntica. Use `--force` para substituir edições locais. O `Info.plist` tem HTTP liberado (`NSAllowsArbitraryLoads = true`) para playlists IPTV que usam endpoints não TLS. Isso reduz a proteção de transporte; prefira HTTPS e não use fontes desconhecidas com credenciais importantes.

## Observações técnicas

- O player `AVPlayer` mantém a mesma instância e troca somente `AVPlayerItem`.
- Sites YouTube/Twitch/Plex podem impor restrições próprias e conteúdos DRM; não há bypass de DRM.
- CarPlay renderiza navegador e cursor **somente** na cena `UIWindowSceneSessionRoleCarPlay` autorizada; `CPInterfaceController` não suporta `pushTemplate` com `UIViewController`.
- O toque remoto usa `elementFromPoint` e `click()` do DOM para links e botões; alguns sites ignoram eventos não confiáveis, inclusive players de vídeo.
- APIs públicas não permitem garantir vídeo no painel de qualquer central apenas com IPA recompilado.
- O modelo de Mapas fornece mapa, não navegação curva-a-curva.

Referências:
- https://github.com/rPlayAI/cafari-lite (MIT, conceito de janela CarPlay)
- https://developer.apple.com/carplay/
- https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/
