# 💊 MedLembrete — Lembrete de medicação com comprovação

Aplicativo Flutter que **lembra o horário do remédio** e pede uma **foto da caixa ou do comprimido** como comprovação de que a dose foi tomada. No momento da confirmação, o app registra também **onde o usuário estava** (em casa ou fora, via GPS) e **se o celular estava parado ou em movimento** (acelerômetro).

| Recurso exigido | Como aparece no app |
|---|---|
| 🔔 **Notificação local** | Lembrete diário no horário de cada remédio. Tocar na notificação abre a tela "Hora do remédio" |
| 📷 **Câmera** | Foto da caixa/comprimido como comprovante, exibida na tela e salva no histórico |
| 📍 **GPS** | Latitude e longitude atuais; compara com a "casa" salva para dizer *em casa* ou *fora* |
| 📈 **Acelerômetro** | Valores X, Y e Z em tempo real; detecta *parado*, *em movimento*, *esquecido* e movimentos bruscos |

### ⭐ Desafio extra (integrações)
- **Foto + coordenadas + mapa na mesma tela** (comprovante no Histórico).
- **Mapa** (OpenStreetMap) com a localização atual e o raio da casa.
- **Notificação por condição**: se o celular fica parado pelo tempo configurado (30 s, 1, 5 ou 15 min), o app avisa "📱 Celular esquecido?" e lista as doses ainda não comprovadas.
- **Movimento brusco**: chacoalhar o celular é detectado e contado.

---

## ▶️ Como rodar

Pré-requisitos: Flutter 3.47+ (Dart 3.13+) e Google Chrome. **Não precisa de Android Studio.**

### 🌐 No Chrome (forma usada na apresentação)

```bash
flutter pub get
flutter run -d chrome
```

No VS Code: escolha **Chrome** como dispositivo na barra inferior e aperte **F5** (ou use a configuração *"MedLembrete (Chrome)"* em `.vscode/launch.json`).

> **Para a apresentação, prefira o modo servidor:** `flutter run -d web-server --web-port 8080` e abra **http://localhost:8080** no seu Chrome normal (configuração *"MedLembrete (apresentação: localhost:8080)"*). No `-d chrome` o Flutter abre um Chrome "de depuração" em que **clicar na notificação não abre o app** (limitação do plugin) e as permissões são esquecidas a cada execução.

Como cada recurso funciona no navegador:

| Recurso | No Chrome do computador |
|---|---|
| 🔔 Notificação | Notificação do Windows. O lembrete é agendado com um `Timer` e dispara **enquanto a aba estiver aberta** (pode estar minimizada) |
| 📷 Câmera | Abre a **webcam** dentro do app (pacote `camera`). Sem webcam: *"Escolher um arquivo de imagem"* |
| 📍 GPS | Localização do navegador (Wi-Fi/Windows). Para simular uma posição: **F12 → ⋮ → More tools → Sensors → Location** |
| 📈 Acelerômetro | PC não tem acelerômetro: o app detecta isso e liga o **modo simulação** (botões *Na mesa*, *Andando* e *Chacoalhar*). Os valores simulados passam pelo **mesmo detector** usado no celular |

### 📱 No celular Android (opcional)

Precisa do Android SDK. Com o celular ligado no USB e a depuração USB ativada: `flutter run`. No celular o acelerômetro e a câmera são reais e as notificações são agendadas no sistema (chegam mesmo com o app fechado).

O mapa precisa de **internet**.

---

## 🧭 Fluxo do aplicativo

```
Abrir o app ──► pede permissão de NOTIFICAÇÃO (no Chrome: aviso com botão "Permitir")
   │
   ├─ Remédios ─► + Adicionar (nome, dosagem, horário) ─► lembrete diário agendado
   │                └─ "Testar" ─► notificação em 10 s (para demonstração)
   │
   ├─ 🔔 Notificação "Hora do remédio" ─► toque ─► Tela da dose
   │        ├─ GPS lido automaticamente ─► pede permissão de LOCALIZAÇÃO
   │        ├─ estado do celular (acelerômetro) ao vivo
   │        └─ Tirar foto (CÂMERA) ─► Confirmar ─► salva o comprovante
   │
   ├─ Histórico ─► comprovante: foto + data/hora + em casa/fora + coordenadas + mapa
   ├─ Local ─► latitude/longitude, "Estou em casa agora", distância e mapa
   └─ Movimento ─► X, Y, Z em tempo real, gráfico, estado, alerta de esquecido
```

## 🔐 Permissões

| Permissão | Plataforma | Quando é pedida | Por quê |
|---|---|---|---|
| `POST_NOTIFICATIONS` | Android 13+ | Ao abrir o app | Exibir os lembretes |
| `SCHEDULE_EXACT_ALARM` | Android 12+ | Ao abrir o app (abre a tela de ajustes se faltar) | Disparar no minuto exato |
| `RECEIVE_BOOT_COMPLETED` | Android | Automática | Reagendar após reiniciar o celular |
| `ACCESS_FINE_LOCATION` / `COARSE` | Android | Na aba Local ou ao comprovar uma dose | Latitude/longitude |
| `INTERNET` | Android | Automática | Carregar o mapa |
| Câmera | Android | Não precisa: o `image_picker` usa o app de câmera do sistema | Foto do comprovante |
| `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSMotionUsageDescription`, `NSPhotoLibraryUsageDescription` | iOS | Na primeira utilização | Textos exigidos pela Apple |
| Notificações | Chrome | Botão **Permitir** do aviso no topo (o navegador só deixa pedir após um clique) | Exibir os lembretes |
| Câmera | Chrome | Ao abrir a webcam | Foto do comprovante |
| Local | Chrome | Na aba Local ou ao comprovar uma dose | Latitude/longitude |

O acelerômetro **não exige permissão** no Android. Se alguma permissão for bloqueada no Chrome, libere clicando no **cadeado** ao lado do endereço do site.

## 📦 Bibliotecas

| Pacote | Uso |
|---|---|
| `flutter_local_notifications` | Notificações locais e agendamento (`zonedSchedule`) |
| `timezone` + `flutter_timezone` | Fuso horário local para agendar no horário certo |
| `image_picker` | Abrir a câmera (celular) e escolher imagem da galeria/arquivo |
| `camera` | Webcam dentro do app no navegador (pré-visualização + foto) |
| `web` | Canvas do navegador para desespelhar a foto da webcam |
| `path_provider` | Pasta de documentos do app para guardar as fotos |
| `geolocator` | Permissão, latitude/longitude e distância até a casa |
| `sensors_plus` | Stream do acelerômetro (X, Y, Z) |
| `flutter_map` + `latlong2` | Mapa OpenStreetMap |
| `shared_preferences` | Salvar remédios, histórico e configurações |

## 🗂️ Organização do projeto

```
lib/
├── main.dart                 # inicializa serviços e roda o app
├── app.dart                  # MaterialApp, tema e navigatorKey
├── core/                     # tema, constantes e formatadores
├── models/
│   ├── medicamento.dart      # remédio + horário do lembrete
│   └── dose.dart             # comprovante: foto + GPS + estado do celular
├── services/                 # regras de negócio e acesso aos recursos
│   ├── notification_service.dart     # 🔔 notificações
│   ├── camera_service.dart           # 📷 câmera (arquivo no celular, data URL na web)
│   ├── espelhar_foto*.dart           # 📷 desfaz o espelho da webcam (só web)
│   ├── location_service.dart         # 📍 GPS e "em casa/fora"
│   ├── movimento_service.dart        # 📈 stream do acelerômetro
│   ├── detector_movimento.dart       # lógica pura: parado/movimento/brusco
│   ├── simulador_acelerometro.dart   # 📈 X, Y, Z simulados (PC sem sensor)
│   ├── alerta_esquecido_service.dart # ⭐ notificação por condição
│   ├── medicamento_repository.dart   # persistência dos remédios
│   ├── dose_repository.dart          # persistência do histórico
│   └── resumo_doses.dart             # doses pendentes e progresso do dia
├── screens/                  # uma pasta por tela
└── widgets/                  # componentes reutilizáveis (mapa, gráfico, cards)
test/                         # testes unitários e de widget
```

**Padrão:** telas não acessam plugins diretamente — chamam os *services*. Os services e repositórios são `ChangeNotifier`s singletons e as telas se atualizam com `ListenableBuilder` (sem pacotes extras de gerência de estado).

## 🌿 Branches e sprints

O desenvolvimento foi feito em sprints, cada uma em sua branch, mergeada na `main` com `--no-ff` (o histórico mostra cada entrega):

| Sprint | Branch | Entrega |
|---|---|---|
| 0 | `sprint-0/setup` | Estrutura de pastas, tema, navegação |
| 1 | `sprint-1/notificacao` | Cadastro de remédios + lembrete com notificação local |
| 2 | `sprint-2/camera` | Foto de comprovação + histórico |
| 3 | `sprint-3/gps` | Latitude/longitude + em casa ou fora |
| 4 | `sprint-4/acelerometro` | X, Y, Z em tempo real + detecção de estado |
| 5 | `sprint-5/integracao` | Desafio extra: comprovante completo, mapa, alerta de esquecido |
| 6 | `sprint-6/docs` | README e roteiro da apresentação |
| 7 | `sprint-7/web` | Rodar no Chrome: webcam, fotos no navegador, lembretes por timer, modo simulação do acelerômetro |

```bash
git log --oneline --graph   # ver o histórico das sprints
```

## ✅ Testes

```bash
flutter analyze
flutter test
```

Os testes cobrem modelos, repositórios, cálculo de distância/“em casa”, o detector de movimento, o resumo do dia, o simulador do acelerômetro, a conversão das fotos para data URL e o cálculo do próximo horário na web.

## 🧪 Checklist antes da apresentação

- [ ] `flutter run -d web-server --web-port 8080` e abrir **http://localhost:8080** no Chrome que será projetado
- [ ] Clicar em **Permitir** no aviso de notificações (e aceitar no pop-up do Chrome)
- [ ] Windows: **Configurações → Sistema → Notificações** ligadas para o Chrome e **"Não perturbe" desligado**
- [ ] Cadastrar um remédio e usar **"Testar"** → a notificação chega em 10 s
- [ ] Clicar na notificação → abrir a webcam → tirar a foto → confirmar
- [ ] Na aba **Local**: permitir localização → "Estou em casa agora"
- [ ] Na aba **Movimento**: modo simulação ligado → *Na mesa* → "Parado" → depois de 30 s chega "📱 Celular esquecido?"
- [ ] Conferir internet para o mapa
- [ ] Testar a webcam do notebook que será usado (ou ter uma imagem da caixa do remédio salva para o plano B)
