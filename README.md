# NEONFLAP — Android

Versão Android do NeonFlap, um jogo estilo Flappy Bird com estética synthwave.
Feito em **Godot 4**, com APK compilado automaticamente pelo GitHub Actions.

O jogo original é em **Python + Pygame** (versão PC). Esta versão é um port com os
mesmos números de física, a mesma curva de dificuldade e a mesma arte — só que
desenhada pela GPU, com bloom nativo no lugar do glow calculado na CPU.

---

## Baixar e instalar no celular

1. Abra a aba **[Releases](../../releases/latest)** deste repositório pelo navegador do celular.
2. Baixe o arquivo `NeonFlap.apk`.
3. O Android vai pedir permissão pra instalar app de fora da loja — libere para o
   navegador (é uma vez só) e confirme a instalação.

Se preferir compilar do zero, é só dar push: o workflow em
`.github/workflows/android.yml` gera o APK e publica na release `latest`.

> O APK é assinado com a keystore de debug. Serve pra instalar e jogar; pra
> publicar na Play Store seria preciso uma keystore de release e um AAB.

---

## Como jogar

Um toque em qualquer lugar da tela faz a nave subir. É só isso.

- **Toque** — pular / confirmar
- **Menu** — toque em JOGAR, SKINS ou ESTATÍSTICAS
- **Pausa** — botão físico de voltar ou tecla `Esc` (no PC)
- **Teclado** (quando roda no PC): `Espaço` pula, `M` corta o som, `N` só a música

---

## Mecânicas

**Dificuldade progressiva** — a cada 5 pontos sobe um degrau: canos mais rápidos
(205 → 380 px/s), abertura menor (208 → 138 px) e espaçamento mais curto. Trava no
degrau 14 (score 70).

**Fases visuais** — a cada 12 pontos a paleta troca com crossfade:
MIDNIGHT → SUNSET → TOXIC → SOLAR → VOID.

**Power-ups** (a partir do 6º ponto) — escudo (absorve uma batida), slow-mo (4,5 s a
55% da velocidade) e ímã (6 s atraindo itens).

**Skins** — seis naves liberadas por recorde: DRIFTER (0), EMBER (10), VIPER (25),
SOLAR (45), WRAITH (70), GHOST (100).

**Recordes** — salvos em `user://save.json`, que no Android fica na área privada do
app. Sobrevive a atualizações e não pede permissão nenhuma.

---

## Estrutura

```
neonflap-godot/
├─ project.godot          retrato 480×854, renderer mobile, HDR 2D ligado
├─ main.tscn              cena única: um Node2D com o script principal
├─ export_presets.cfg     preset Android (arm64 + armv7, sem gradle build)
├─ scripts/
│  ├─ cfg.gd              todos os números do jogo (mesmos do config.py da versão PC)
│  ├─ main.gd             telas, entrada por toque e o _draw() de tudo
│  ├─ world.gd            simulação: física, canos, colisão, power-ups
│  ├─ background.gd       céu, sol retrô, skyline em parallax, grid
│  ├─ art.gd              desenho procedural e dígitos de 7 segmentos
│  ├─ sfx.gd              efeitos e trilha
│  └─ save_data.gd        recordes e estatísticas em JSON
├─ assets/audio/*.ogg     176 KB, gerados pelo sintetizador da versão PC
└─ .github/workflows/     build automático do APK
```

### Decisões que valem nota

- **Bloom em vez de blur na CPU.** Na versão PC o halo neon era um borrão calculado
  por redução/ampliação de superfícies. Aqui as cores passam de 1.0 (HDR 2D ligado) e
  o `WorldEnvironment` faz o glow na GPU — de graça, e melhor.
- **Desenho em modo imediato.** Tudo acontece num único `_draw()`, igual à versão PC.
  Sem nós por cano, sem cenas instanciadas: menos alocação e o mesmo código que já
  estava validado.
- **Áudio pré-renderizado.** Os `.ogg` saíram do mesmo sintetizador numpy da versão
  PC (`tools/bake_audio.py`), então o som é idêntico — mas sem custo de inicialização
  no celular.
- **Sem gradle build.** O export usa o template pré-compilado do Godot, o que dispensa
  compilar código nativo no CI e deixa o build em poucos minutos.
- **Colisão por círculo** contra os retângulos do cano, e geração de canos com limite
  de salto vertical — o jogo nunca sorteia uma sequência impossível.

---

Feito por Robert Gomes.
