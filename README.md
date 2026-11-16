# StreamPlay — iPhone + CarPlay (SwiftUI / UIKit / AVKit)

**Status:** gerador Python autossuficiente + projeto-fonte Xcode (sem frameworks de terceiros) com player HLS no iPhone e cenas CarPlay. O arquivo `.ipa` não pode ser compilado neste ambiente Linux; o projeto e o `project.pbxproj` foram validados estruturalmente, mas a compilação do Swift/iOS exige Xcode no macOS. Streams HLS externos de demonstração podem ficar indisponíveis.

## Compatibilidade importante

- `CPInterfaceController.pushTemplate` **só aceita `CPTemplate`**. Nenhum `UIViewController` ou `AVPlayerLayer` pode ser colocado nessa stack. `PlayerViewController.swift` serve apenas às cenas de UI controladas pelo app (iPhone), não à tela CarPlay.
- **CarPlay áudio:** requer aprovação da Apple e o entitlement gerenciado `com.apple.developer.carplay-audio` associado ao provisioning profile. Com essa aprovação, `CarPlayMode = audio` mostra Home/Search/Settings e `CPNowPlayingTemplate` para reprodução de áudio (incluindo a faixa de áudio de um HLS de vídeo).
- **CarPlay vídeo estacionado:** iOS **27+**, carro que suporte *video in car*, **AirPlay video streaming** e entitlement gerenciado **`com.apple.developer.carplay-video`**. Com aprovação, defina `CarPlayMode = video` no `Info.plist`; `CPPlaybackConfiguration(preferredPresentation: .video, …)` orienta a apresentação pelo sistema. O sistema bloqueia o vídeo quando o veículo está em movimento. `CPSessionConfiguration.supportsVideoPlayback` informa se a sessão oferece suporte, não se o vídeo está disponível neste instante.
- **Se o app oferecer conteúdo adequado a áudio e vídeo, a Apple recomenda combinar os entitlements aprovados**. Incluímos um exemplo `AudioVideo.entitlements.example`; use-o apenas quando ambos tiverem sido autorizados no seu App ID e provisioning profile.
- **Personal Team, AltStore e Sideloadly não fornecem esses entitlements**. Sem autorização, o app roda no iPhone, mas **não ganha um ícone funcional no CarPlay real**. Não existe flag ou alteração de Info.plist que substitua a autorização. O áudio por Bluetooth/AirPlay do iPhone continua disponível, mesmo sem interface CarPlay customizada.
- A Apple é responsável pela apresentação do vídeo CarPlay. A tela de controles `CPListTemplate` incluída é um fallback; o sistema pode apresentar vídeo no carro compatível quando uma lista com `playbackConfiguration = .video` iniciar a reprodução. A integração efetiva exige testes em veículo/CarPlay Simulator.

## Arquitetura

```
StreamPlay/
├─ StreamPlay.xcodeproj/
│  ├─ project.pbxproj
│  ├─ project.xcworkspace/
│  └─ xcshareddata/xcschemes/StreamPlay.xcscheme
├─ StreamPlay/
│  ├─ App.swift                   # @main UIApplicationDelegate + Scene configurations
│  ├─ SceneDelegate.swift         # UIWindowScene para o iPhone; UIHostingController
│  ├─ CarPlaySceneDelegate.swift  # CPTabBarTemplate + listas + Player system
│  ├─ ContentView.swift           # SwiftUI, tabs, NavigationStack, VideoPlayer
│  ├─ PlayerViewController.swift  # AVPlayerLayer UIKit, UIKit representable e AirPlay picker
│  ├─ ChannelViewModel.swift      # único AVPlayer, AVPlayerItem, áudio, metadados
│  ├─ Models.swift                # Channel, CarPlayMode
│  ├─ ChannelService.swift        # MockChannelService assíncrono
│  ├─ RemoteCommandController.swift # MPRemoteCommandCenter
│  └─ Info.plist                  # duas scene roles e background audio
├─ CarPlayEntitlements/
│  ├─ Audio.entitlements.example
│  └─ Video.entitlements.example
├─ scripts/build-unsigned-ipa.sh
├─ StreamPlay/Assets.xcassets/AppIcon.appiconset/ # ícone universal (1024 px)
├─ gen_xcodeproj.py           # gera TODO o projeto apenas com Python
└─ README.md
```

## Regerar o projeto usando somente Python

O arquivo `gen_xcodeproj.py` inclui os nove fontes Swift, o manifesto de cenas, o scheme,
os arquivos de entitlement de exemplo, o script de empacotamento e este README.

```bash
# Gera todos os arquivos em pasta nova, a partir apenas do Python
python3 gen_xcodeproj.py --output ./NovoStreamPlay

# Gerar dentro da pasta em que o script está (preserva arquivos existentes)
python3 gen_xcodeproj.py

# Sobrescreve arquivos existentes. ATENÇÃO: descarta edições no código/projeto.
python3 gen_xcodeproj.py --force
```

Esse comando não compila um IPA em Linux/Windows. O projeto precisa ser aberto
no Xcode (macOS). O `Info.plist` usa `GENERATE_INFOPLIST_FILE = NO` e é gerado
fisicamente em `StreamPlay/Info.plist`; o `project.pbxproj` referencia exatamente
essa localização. O manifesto declara explicitamente as classes
`UIWindowScene` e `CPTemplateApplicationScene` com seus delegados.

Os IDs do `.pbxproj` são determinísticos (MD5 de 24 caracteres), o que facilita
acompanhar mudanças no controle de versão. O `--force` recria um estado limpo e
pode sobrescrever configurações de assinatura ou alterações feitas pelo Xcode.

## Compilar no Xcode

1. Requer macOS + Xcode 27 para compilar o trecho mais novo (`CPPlaybackConfiguration`, iOS 27). Os arquivos usam sintaxe Swift 5.9+, e o projeto mantém `SWIFT_VERSION = 5.0` para o *Swift 5 language mode* aceito pelo Xcode — não significa que o compilador seja Swift 5.0.
2. Descompacte e abra `StreamPlay.xcodeproj`. Selecione o scheme `StreamPlay`.
3. Em **TARGETS > StreamPlay > Signing & Capabilities**, mude Bundle Identifier para um identificador exclusivo, por exemplo `com.seudominio.streamplay`.
4. Selecione **Personal Team** e **Automatically manage signing**; selecione seu iPhone conectado ou simulador.
5. Clique **Run**. O iPhone mostra canais HLS de teste; troque os endereços em `MockChannelService` pelos seus HLS autorizados.
6. Teste trocar de canal; o objeto `AVPlayer` continua o mesmo e `replaceCurrentItem` substitui apenas o item. `VideoPlayer` e `PlayerLayerView` podem compartilhar o mesmo player; o exemplo apresenta `VideoPlayer` no iPhone.

## Habilitar CarPlay com conta/autorização compatível

1. Inscreva-se no Apple Developer Program e solicite à Apple o CarPlay entitlement apropriado à categoria do app, sujeito a avaliação. App de vídeo requer categoria vídeo e fontes/licenças válidas.
2. Após aprovação, configure o App ID e provisioning profile com a capacidade gerenciada aprovada, segundo as instruções da Apple.
3. Escolha **um exemplo** em `CarPlayEntitlements/`: áudio, vídeo, ou áudio+vídeo. Use o exemplo combinado apenas se ambos os entitlements estiverem aprovados. Copie-o para `StreamPlay/StreamPlay.entitlements` (remova `.example`).
4. Em **Build Settings > Code Signing Entitlements**, use o caminho relativo `StreamPlay/StreamPlay.entitlements`, para Debug e Release; nunca insira a chave sem autorização no profile.
5. Para **áudio**, deixe `CarPlayMode = audio` em `Info.plist` e use **carplay-audio** quando aprovado.
6. Para **vídeo**, altere para `CarPlayMode = video` e use **carplay-video** quando aprovado, com iOS 27+ e veículo/Simulator compatível. Para os dois modos, utilize o exemplo combinado somente com ambas as autorizações. O player deve ter suporte AirPlay: `AVPlayer.allowsExternalPlayback = true` e `AVRoutePickerView` estão incluídos.
7. Para validação em carro real, use um provisioning profile que inclua o entitlement; conectar ou confiar no app com Sideloadly não bypassa essa exigência.

## Criar `.ipa`

### Opção A — Xcode Archive (perfil de desenvolvimento/distribuição compatível)

1. Selecione **Any iOS Device (arm64)**, depois **Product > Archive**.
2. No **Organizer > Distribute App**, escolha a opção de distribuição permitida por sua conta e perfil.
3. Uma exportação de desenvolvimento/distribuição pode gerar um IPA assinado; o caminho exato depende das autorizações e do tipo de conta. Uma Personal Team pode restringir Archive/Export; se não for possível, use o método abaixo.

### Opção B — gerar IPA NÃO ASSINADO para re-signing

No Terminal (macOS):

```bash
cd StreamPlay
./scripts/build-unsigned-ipa.sh
```

Resultado: `dist/StreamPlay-unsigned.ipa` contendo `Payload/StreamPlay.app`. Esse IPA **não é instalável como está**. Use AltStore ou Sideloadly para assinar com seu Apple ID (dentro das limitações da conta), ou prefira instalar diretamente com o Xcode. Essa re-assinatura não cria CarPlay managed entitlements nem autoriza uma categoria restrita. Com Apple ID gratuito, aplicativos instalados por métodos de sideload frequentemente precisam ser renovados periodicamente, conforme a ferramenta e a assinatura.

## Debug CarPlay

1. Inicie um simulador de iPhone no Xcode; em **Simulator > I/O > External Displays > CarPlay**, abra a tela. Dependendo da versão, instale também o **CarPlay Simulator** em *Additional Tools for Xcode* da Apple; o simulador de vídeo exige a configuração de veículo compatível.
2. Confirme que a aplicação tem entitlement aprovado; sem ele, o ícone não deve aparecer na Home do CarPlay.
3. Coloque breakpoints em `templateApplicationScene(_:didConnect:)`, `installRootTemplate()`, e `select(_:)`.
4. Veja logs em Xcode Console para erros de `pushTemplate`/`setRootTemplate`. `CPListItem.handler` chama `completion()` em todos os caminhos.
5. Para teste em dispositivo real, use iPhone com iOS compatível, CarPlay habilitado e app instalado com provisioning autorizado. Em um carro que suporte vídeo, teste **somente estacionado**, com suporte de vídeo habilitado pelo fabricante.
6. Verifique áudio, troca de streams, interrupções por chamada, retorno do background, conexão/desconexão CarPlay e alterações de disponibilidade do vídeo. Use **AVPlayerItem.status**, Xcode Instruments, Console e o Network Link Conditioner para analisar HLS.

## Limitações/proximos passos

- Dados e URLs HLS são demos públicos; podem não ser lives ou eventualmente ficar indisponíveis. Não integram canais comerciais nomeados.
- O modo **Search** no CarPlay é uma lista ordenada. `CPSearchTemplate` é voltado para apps de navegação e um teclado arbitrário não pode ser implementado com templates de mídia.
- Evite publicar listas M3U de terceiros sem licença ou transmitir conteúdo protegido sem autorização.
- Para produção: testes de integração, retry exponencial, tratamento de DRM/FairPlay Streaming se necessário, autenticação de catálogo, política de caching, thumbnails válidas e métricas de erros de streaming.
- `objectVersion = 56`, `LastUpgradeCheck = 1500` e `CreatedOnToolsVersion = 15.0` são metadados coerentes para um projeto OpenStep legível por ferramentas antigas; **não** tornam as APIs iOS 27 compiláveis no Xcode 15. O compilador usado deve trazer o iOS 27 SDK.
- O app inclui um AppIcon de demonstração gerado com Python stdlib (PNG RGB opaco de 1024×1024). Substitua-o pela identidade visual da marca antes de publicar.
- Skip forward/backward ficam intencionalmente desativados por se tratar de demos de streaming live. Configure handlers de seek somente quando houver VOD com segmentos buscáveis.
- Não foi feita compilação via Xcode neste ambiente, portanto não há garantia de build ou de reprodução no hardware sem validação macOS.

## Referências Apple

- https://developer.apple.com/documentation/carplay/displaying-content-in-carplay
- https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements
- https://developer.apple.com/documentation/carplay/cpinterfacecontroller
- https://developer.apple.com/documentation/carplay/cpplaybackconfiguration
- https://developer.apple.com/videos/play/wwdc2026/212/
- https://developer.apple.com/carplay/
