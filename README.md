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

Pré-requisitos: Flutter 3.47+ (Dart 3.13+), **Android Studio com Android SDK** (plataforma **API 37**) e um celular Android ou emulador.

```bash
flutter pub get
flutter run
```

> **Celular real é o ideal** — o emulador não tem acelerômetro de verdade (dá para simular em *Extended controls → Virtual sensors*) e a câmera é virtual. Para o GPS no emulador, defina uma posição em *Extended controls → Location*.

O mapa precisa de **internet**.

---

## 🧭 Fluxo do aplicativo

```
Abrir o app ──► pede permissão de NOTIFICAÇÃO
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

O acelerômetro **não exige permissão** no Android.

## 📦 Bibliotecas

| Pacote | Uso |
|---|---|
| `flutter_local_notifications` | Notificações locais e agendamento (`zonedSchedule`) |
| `timezone` + `flutter_timezone` | Fuso horário local para agendar no horário certo |
| `image_picker` | Abrir a câmera e capturar a foto |
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
│   ├── camera_service.dart           # 📷 câmera
│   ├── location_service.dart         # 📍 GPS e "em casa/fora"
│   ├── movimento_service.dart        # 📈 stream do acelerômetro
│   ├── detector_movimento.dart       # lógica pura: parado/movimento/brusco
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

```bash
git log --oneline --graph   # ver o histórico das sprints
```

## ✅ Testes

```bash
flutter analyze
flutter test
```

Os testes cobrem modelos, repositórios, cálculo de distância/“em casa”, o detector de movimento e o resumo do dia.

## 🧪 Checklist antes da apresentação

- [ ] `flutter run` no celular que será usado na apresentação
- [ ] Permitir **notificações** (e "Alarmes e lembretes", se o Android pedir)
- [ ] Cadastrar um remédio e usar **"Testar"** → a notificação chega em 10 s
- [ ] Tocar na notificação → tirar a foto → confirmar
- [ ] Na aba **Local**: permitir localização → "Estou em casa agora"
- [ ] Na aba **Movimento**: deixar o celular na mesa → muda para "Parado" → depois de 30 s chega "📱 Celular esquecido?"
- [ ] Conferir internet para o mapa
- [ ] Desativar o modo "Não perturbe"
