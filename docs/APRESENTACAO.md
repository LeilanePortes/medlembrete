# 🎤 Roteiro da apresentação — MedLembrete (máx. 15 min)

> Sugestão para grupo de 4 a 6 pessoas. Cada bloco tem um responsável; quem não fala no bloco opera o celular/projeção.
> **Espelhe a tela do celular** (scrcpy, Vysor ou "Transmitir tela") para a turma ver a demonstração ao vivo.

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
Sprints em branches (`sprint-0/setup` … `sprint-6/docs`) → print do `git log --oneline --graph`.

### Slide 5 — Bibliotecas
Tabela do README (`flutter_local_notifications`, `image_picker`, `geolocator`, `sensors_plus`, `flutter_map`, `shared_preferences`…).

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

### Slide 7 — 📷 Câmera
Trecho: `lib/services/camera_service.dart`
```dart
final foto = await _picker.pickImage(
  source: ImageSource.camera, maxWidth: 1280, imageQuality: 80);
await foto.saveTo('${documentos.path}/comprovantes/dose_<timestamp>.jpg');
```
**Explicar:** `image_picker` abre a câmera do sistema; a foto é copiada para a pasta do app (`path_provider`) e exibida com `Image.file`.

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

**Antes de começar** (já deixar feito): app instalado, permissões concedidas, "casa" definida, 1 remédio cadastrado, internet ligada, "Não perturbe" desligado, brilho no máximo.

1. **Notificação** — Remédios → *Adicionar* "Vitamina D, 1 cápsula" → Salvar. Clicar em **Testar** → bloquear a tela → em 10 s chega a notificação.
2. **Câmera** — Tocar na notificação → abre "Hora do remédio" → **Tirar foto** de uma caixa de remédio → mostrar a pré-visualização → **Confirmar que tomei**.
3. **GPS** — Na mesma tela, mostrar o card "Em casa" com as coordenadas. Ir à aba **Local** → *Atualizar localização* → latitude/longitude, distância e mapa.
4. **Acelerômetro** — Aba **Movimento** → mexer o celular (X, Y, Z mudam e o gráfico reage) → **chacoalhar** (contador de bruscos sobe) → apoiar na mesa → "Parado" → em 30 s chega a notificação "📱 Celular esquecido?".
5. **Integração** — Aba **Histórico** → abrir o comprovante: foto + horário + em casa + coordenadas + estado do celular + mapa.

### Plano B
- Notificação não chegou? Verificar "Alarmes e lembretes" nas configurações do app; usar **Testar** de novo.
- Câmera do emulador falhou? Botão **"Sem câmera? Escolher da galeria"**.
- GPS demorando (sala fechada)? O app usa a última posição conhecida; chegar perto da janela.
- Sem internet? O mapa fica cinza, mas latitude/longitude continuam aparecendo.

---

## ❓ Perguntas prováveis do professor

- **Por que `zonedSchedule` e não `Future.delayed`?** — O agendamento fica no sistema operacional (AlarmManager): a notificação chega mesmo com o app fechado ou após reiniciar o celular (`RECEIVE_BOOT_COMPLETED`).
- **Como sabe que está em casa?** — O usuário salva a casa uma vez; depois calculamos a distância (fórmula de Haversine via `Geolocator.distanceBetween`). Até 100 m = em casa (margem para a imprecisão do GPS).
- **Como sabe que o celular está parado?** — Com o celular parado o acelerômetro mede só a gravidade (~9,8 m/s²) e quase não varia. Calculamos o desvio padrão da magnitude no último segundo: abaixo de 0,3 = parado.
- **Por que a câmera não pede permissão no Android?** — O `image_picker` usa o app de câmera do sistema via *intent*; quem acessa o hardware é o app de câmera, não o nosso.
- **Onde ficam os dados?** — No próprio celular: `shared_preferences` (JSON) e as fotos na pasta de documentos do app.
