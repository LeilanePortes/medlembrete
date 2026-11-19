# 🎤 Roteiro da apresentação — MedLembrete (máx. 15 min)

> Sugestão para grupo de 4 a 6 pessoas. Cada bloco tem um responsável; quem não fala no bloco opera o notebook/projeção.
> O app roda **no Chrome do notebook** (`flutter run -d web-server --web-port 8080` → http://localhost:8080). Dica: **F12 → ícone de celular (Toggle device toolbar)** deixa a tela com formato de celular na projeção.

| Tempo | Bloco | Quem |
|---|---|---|
| 0:00–1:30 | Tema e problema | Pessoa 1 |
| 1:30–3:00 | Organização do projeto e bibliotecas | Pessoa 2 |
| 3:00–5:00 | 🔔 Notificação (código + demo) | Pessoa 3 |
| 5:00–7:00 | 📷 Câmera (código + demo) | Pessoa 4 |
| 7:00–9:00 | 📍 GPS (código + demo) | Pessoa 5 |
| 9:00–11:00 | 📈 Acelerômetro (código + demo) | Pessoa 6 |
| 11:00–13:30 | ⭐ Integração / desafio extra (demo completa) | Pessoa 1 |
| 13:30–15:00 | Permissões, conclusão e perguntas | Pessoa 2 |

---

## Slides

### Slide 1 — Capa
**MedLembrete** · *Lembrete de medicação com comprovação*
Nomes do grupo · disciplina · data. Ícone de pílula + celular.

### Slide 2 — O problema
- Esquecer o remédio ou **não lembrar se já tomou** é comum (idosos, tratamentos contínuos).
- Cuidadores e familiares querem **ter certeza** de que a dose foi tomada.

### Slide 3 — A solução e as 4 funcionalidades
| | |
|---|---|
| 🔔 Notificação | avisa o horário do remédio |
| 📷 Câmera | foto da caixa/comprimido = comprovação |
| 📍 GPS | registra se estava **em casa** ou **fora** |
| 📈 Acelerômetro | indica se o celular está **parado (esquecido)** ou **em movimento** |

### Slide 4 — Organização do projeto
Mostrar a árvore `lib/` do README. Frase-chave: *"As telas não falam com os plugins: cada recurso tem um **service** próprio."*
Sprints em branches (`sprint-0/setup` … `sprint-7/web`) → print do `git log --oneline --graph`.
Frase-chave 2: *"O mesmo código roda no Android e no Chrome; onde a web é diferente, o service decide com `kIsWeb`."*

### Slide 5 — Bibliotecas
Tabela do README (`flutter_local_notifications`, `camera`, `image_picker`, `geolocator`, `sensors_plus`, `flutter_map`, `shared_preferences`…).

### Slide 6 — 🔔 Notificação
Trecho: `lib/services/notification_service.dart` → `agendarLembreteDiario`
```dart
await _plugin.zonedSchedule(
  id: m.id,
  title: '💊 Hora do remédio: ${m.nome}',
  scheduledDate: horario,                       // TZDateTime no fuso local
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time, // repete todo dia
  payload: 'dose:${m.id}',                       // abre a tela certa ao tocar
);
```
**Explicar:** fuso horário com `timezone`; `payload` identifica o remédio; o toque abre a tela da dose (`MainShell._abrirPeloPayload`).

**No Chrome** o navegador não agenda notificações futuras, então o service usa um `Timer` (`_agendarNaWeb`) e mostra a notificação com `show()` na hora certa:
```dart
if (kIsWeb) {
  _timersWeb[id] = Timer(quando.difference(DateTime.now()), () {
    mostrarAgora(id: id, titulo: ..., payload: 'dose:${m.id}');
    if (diario) _agendarNaWeb(..., quando: quando.add(Duration(days: 1)));
  });
}
```

### Slide 7 — 📷 Câmera
Trecho: `lib/services/camera_service.dart`
```dart
final foto = await _picker.pickImage(
  source: ImageSource.camera, maxWidth: 1280, imageQuality: 80);
await foto.saveTo('${documentos.path}/comprovantes/dose_<timestamp>.jpg');
```
**Explicar:** `image_picker` abre a câmera do sistema; a foto é copiada para a pasta do app (`path_provider`).

**No Chrome:** a tela `WebcamScreen` liga a webcam com o pacote `camera` (`CameraController` + `CameraPreview` + `takePicture()`). Como a web não tem pasta de arquivos, a foto vira texto (`data:image/jpeg;base64,...`) e fica salva junto com a dose. A webcam entrega a foto espelhada (tipo selfie), então `desespelharFoto` inverte a imagem num canvas para o nome da caixa ficar legível.

### Slide 8 — 📍 GPS
Trecho: `lib/services/location_service.dart` → `obterPosicaoAtual`
```dart
if (!await Geolocator.isLocationServiceEnabled()) ...   // GPS ligado?
var permissao = await Geolocator.checkPermission();
if (permissao == LocationPermission.denied) {
  permissao = await Geolocator.requestPermission();      // pede ao usuário
}
final posicao = await Geolocator.getCurrentPosition(...);
final distancia = Geolocator.distanceBetween(lat, lon, casa.lat, casa.lon);
final emCasa = distancia <= 100; // metros
```

### Slide 9 — 📈 Acelerômetro
Trecho: `lib/services/movimento_service.dart` e `detector_movimento.dart`
```dart
accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
    .listen((e) => detector.adicionar(e.x, e.y, e.z, DateTime.now()));

magnitude = sqrt(x*x + y*y + z*z);   // parado ≈ 9,8 m/s² (gravidade)
// desvio padrão da magnitude em ~1 s:
// baixo → PARADO · alto → EM MOVIMENTO · parado > limite → ESQUECIDO
```
**No Chrome do PC** não existe acelerômetro: se nenhuma leitura chega em 3 s, o `MovimentoService` liga o **modo simulação** (`SimuladorAcelerometro`), que gera X, Y, Z de "celular na mesa", "andando" ou "chacoalhando". **Ser transparente:** os valores são simulados, mas passam pelo **mesmo detector** do celular, e é isso que estamos demonstrando. Se alguém abrir o app no navegador de um celular (com HTTPS), as leituras são reais.

### Slide 10 — ⭐ Integração (desafio extra)
- Comprovante = **foto + data/hora + latitude/longitude + em casa/fora + estado do celular**, com **mapa** na mesma tela.
- **Notificação por condição:** celular parado por X segundos → "📱 Celular esquecido?" listando doses pendentes.
- **Movimento brusco** detectado e contado.

### Slide 11 — Permissões
Tabela de permissões do README. Destacar: notificação (Android 13+), alarme exato (Android 12+), localização em tempo de execução, acelerômetro sem permissão no Android.

### Slide 12 — Conclusão
O que aprendemos (plugins nativos, permissões, streams, agendamento) · próximos passos (compartilhar comprovante com cuidador, relatório semanal) · **Obrigado!**

---

## 🎬 Roteiro da demonstração ao vivo

**Antes de começar** (já deixar feito): app aberto em http://localhost:8080 no Chrome normal, permissões de notificação, câmera e local concedidas, "casa" definida, 1 remédio cadastrado, internet ligada, "Não perturbe" do Windows desligado, uma caixa de remédio em mãos.

1. **Notificação** — Remédios → *Adicionar* "Vitamina D, 1 cápsula" → Salvar. Clicar em **Testar** → minimizar o Chrome → em 10 s aparece a notificação do Windows.
2. **Câmera** — Clicar na notificação → abre "Hora do remédio" → **Tirar foto** → a webcam liga → mostrar a caixa do remédio → foto → **Confirmar que tomei**.
3. **GPS** — Na mesma tela, mostrar o card "Em casa" com as coordenadas. Ir à aba **Local** → *Atualizar localização* → latitude/longitude, distância e mapa.
4. **Acelerômetro** — Aba **Movimento** → explicar o cartão "Modo simulação" → **Andando** (X, Y, Z oscilam, gráfico reage, "Em movimento") → **Chacoalhar** (contador de bruscos sobe) → **Na mesa** → "Parado" → em 30 s chega a notificação "📱 Celular esquecido?".
5. **Integração** — Aba **Histórico** → abrir o comprovante: foto + horário + em casa + coordenadas + estado do celular + mapa.

### Plano B
- Notificação não chegou? Conferir o "Não perturbe" do Windows e se o Chrome pode notificar (Configurações → Sistema → Notificações); clicar em **Testar** de novo. Clicar nela não abriu o app? Você está no `-d chrome`: use o botão **Tomar** do remédio.
- Webcam não liga? Cadeado ao lado do endereço → Câmera → Permitir. Ou **"Sem webcam? Escolher um arquivo de imagem"** com uma foto da caixa já salva.
- GPS falhou? Ativar a localização do Windows, ou simular: **F12 → ⋮ → More tools → Sensors → Location**.
- Sem internet? O mapa fica cinza, mas latitude/longitude continuam aparecendo.

---

## ❓ Perguntas prováveis do professor

- **Por que `zonedSchedule` e não `Future.delayed`?** — No celular o agendamento fica no sistema operacional (AlarmManager): a notificação chega mesmo com o app fechado ou após reiniciar o celular (`RECEIVE_BOOT_COMPLETED`). No navegador isso não existe (o plugin lança `UnsupportedError`), então na web usamos um `Timer`, que funciona enquanto a aba estiver aberta.
- **O acelerômetro é de verdade?** — No celular, sim. No notebook não existe o sensor; o app detecta isso sozinho e usa valores simulados. A lógica que interpreta X, Y, Z (parado/movimento/esquecido/brusco) é a mesma e tem testes automatizados.
- **Como sabe que está em casa?** — O usuário salva a casa uma vez; depois calculamos a distância (fórmula de Haversine via `Geolocator.distanceBetween`). Até 100 m = em casa (margem para a imprecisão do GPS).
- **Como sabe que o celular está parado?** — Com o celular parado o acelerômetro mede só a gravidade (~9,8 m/s²) e quase não varia. Calculamos o desvio padrão da magnitude no último segundo: abaixo de 0,3 = parado.
- **Por que a câmera não pede permissão no Android?** — O `image_picker` usa o app de câmera do sistema via *intent*; quem acessa o hardware é o app de câmera, não o nosso. No Chrome é o nosso app que liga a webcam, por isso o navegador pede a permissão.
- **Onde ficam os dados?** — No próprio dispositivo: `shared_preferences` (JSON). No celular as fotos ficam na pasta de documentos do app; no Chrome ficam no armazenamento local do navegador (`localStorage`), como data URL.
