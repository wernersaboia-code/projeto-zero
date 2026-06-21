# ProjetoZero — Documento de Design

**Gênero:** Grande estratégia geopolítica moderna (turn-based)
**Engine:** Godot 4.6 (GL Compatibility mode)
**Ambientação:** 2025–2030, mapa da Terra em hex grid 320×200
**Inspiradores:** Strategic Command, Making History, Hearts of Iron, Civilization VI

---

## 1. Visão Geral

ProjetoZero é um jogo de grande estratégia onde o jogador controla uma nação em um mapa hexagonal da Terra, tomando decisões diplomáticas, econômicas, militares e tecnológicas para prosperar num mundo instável. O jogo começa em janeiro de 2025 com 119 nações reais, suas relações diplomáticas, recursos naturais e terrenos correspondentes à geografia real.

### Pilares de design
- **Geopolítica autêntica** — nações reais com posições geográficas corretas, relações iniciais baseadas em dados de 2020
- **Economia interligada** — cadeias de produção (matéria-prima → processado → manufaturado), comércio internacional
- **Decisões significativas** — cada turno (1 dia) importa; recursos são escassos, diplomacia é complexa
- **Profundidade emergente** — pequenas decisões escalam em consequências geopolíticas

### Público-alvo
Jogadores de grand strategy (HoI4, EU4, Making History, Strategic Command) que querem um mapa da Terra realista com mecânicas modernas.

---

## 2. Mundo e Ambientação

### Mapa
- **Grid:** 320 colunas × 200 linhas = 64.000 hexágonos
- **Projeção:** Equiretangular (col 0 = longitude -180°, col 319 = longitude +180°, row 0 = latitude +90°N, row 199 = latitude -90°S)
- **Fontes de dados:**
  - `terrain.bmp` (5616×2160, 8bpp indexed) — tipos de terreno exatos
  - `provinces.bmp` (5616×2160) — fronteiras de províncias
  - `rivers.bmp` (5616×2160) — rede hidrográfica
  - `earth_heightmap.png` (320×200) — elevação para visual 3D e rios

### Tipos de terreno (13)
| ID | Tipo | Movement Cost | Defense | Passable | Fonte (palette index) |
|----|------|---------------|---------|----------|----------------------|
| 0 | Ocean | 999 | 0.0 | Não | 254 |
| 1 | Shallow Water | 3.0 | -0.2 | Sim | Derivado (distância costa) |
| 2 | Plains | 1.0 | 0.0 | Sim | 16-23, 36-39, 48-55, 96-103, 128-135, 255 |
| 3 | Forest | 2.0 | 0.3 | Sim | 8-15, 176-183, 200-207 |
| 4 | Woods | 1.5 | 0.2 | Sim | 56-63, 112-119 |
| 5 | Hills | 1.5 | 0.2 | Sim | 40-47, 88-95, 144-175, 184-191, 208-215 |
| 6 | Mountains | 999 | 0.5 | Não | 0-7, 28-35, 72-87 |
| 7 | Desert | 1.0 | -0.1 | Sim | 64-71, 136-143 |
| 8 | Jungle | 1.5 | 0.3 | Sim | 104-111, 192-199 |
| 9 | Marsh | 1.5 | 0.4 | Sim | 120-127, 224-227 |
| 10 | Urban | 1.2 | 0.4 | Sim | 24-27 |
| 11 | Arctic | 1.0 | 0.0 | Sim | 216-223, 228-231 |
| 12 | Tundra | 1.5 | 0.1 | Sim | (não mapeado ainda; arctic cobre) |

### Nações (119)
Dados em `assets/data/sr2030_regions.json`:
- `id`: identificador único (ex: 2989 = EUA)
- `tag`: código ISO 3 letras (ex: USA, CAN, BRA)
- `name`: nome completo
- `color`: cor RGBA em hex (para visualização no mapa)
- `capitalId`: ID da capital
- `capitalName`: nome da capital

### Relações diplomáticas iniciais
Fonte: `Modern2020.csv` (incluído em `assets/data/` como referência)
- **DipRel** (-1.0 a +1.0): relação diplomática (aliança/aliança negativa)
- **CivRel** (-1.0 a +1.0): relação civil (comércio/cultural)
- **BelliRel** (0.0 a 1.0): beligerância (probabilidade de declaração de guerra)

Exemplos:
- EUA (2989) ↔ Canadá (2499): DipRel +0.9, forte aliança
- EUA (2989) ↔ Irã (1102): DipRel -0.9, hostil
- Rússia (617) ↔ EUA (2989): DipRel -0.9, hostil

---

## 3. Mecânicas Core

### 3.1 Economia

#### Recursos (11 tipos)
**Matérias-primas:**
| ID | Recurso | Fontes de terreno | Uso |
|----|---------|-------------------|-----|
| 0 | Agriculture | Plains, Forest, Urban | Consumo populacional, input para Petróleo |
| 1 | Rubber | Forest, Jungle, Woods | Input para Bens de Consumo, Industriais, Militares |
| 2 | Timber | Forest, Woods, Jungle | Construção |
| 3 | Petroleum | Desert, Hills, Shallow Water | Energia, plásticos, combustível |
| 4 | Coal | Plains, Hills, Mountains | Energia, aço |
| 5 | Metal Ore | Hills, Mountains | Indústria |
| 6 | Uranium | Mountains, Desert, Arctic | Energia nuclear |

**Processados:**
| ID | Recurso | Recipe (inputs por unidade) |
|----|---------|------------------------------|
| 7 | Electric Power | Petroleum 1.786 + Coal 6.6 + Uranium 0.026 |
| 8 | Consumer Goods | Rubber 0.1 + Petroleum 10 + Metal Ore 3.5 + Electric 10 + Industry 0.25 |
| 9 | Industry Goods | Rubber 0.05 + Petroleum 30 + Coal 5 + Metal Ore 14.8 + Electric 38 |
| 10 | Military Goods | Rubber 0.1 + Petroleum 75 + Metal Ore 39.5 + Electric 100 + Industry 0.5 |

#### Cadeia de produção
```
Matérias-primas → Electric Power → Industry Goods → Consumer/Military Goods
                ↗
            Population consume (Agriculture, Electric, Consumer)
```

#### Comércio
- `MarketSystem.process_trade()` executa a cada tick
- Nações com excesso vendem 50% do balanço positivo
- Nações com déficit compram
- Preço = base_price × clamp(2.0 / (1.0 + supply/demand), 0.5, 2.0)

#### Tesouro
- `nation.treasury`: dinheiro disponível
- GDP = soma(valor × produção por recurso)
- Receita = GDP × 0.3 por tick
- Comércio afeta treasury diretamente

### 3.2 Diplomacia (planejada)
- **Relações:** DipRel, CivRel, BelliRel por par de nações
- **Tratados:** alianças, não-agressão, comércio preferencial
- **Estados:** paz, tensão, crise, guerra, ocupação
- **Ações:** declarar guerra, fazer paz, propor aliança, embargo comercial
- **Eventos scriptados:** baseados em `Leaders2020.csv` (~30.000 eventos)

### 3.3 Militar (planejado)
- **Unidades:** infantaria, blindados, aéreos, navais, nucleares
- **Movimento:** hex grid com terrain movement_cost
- **Combate:** attack/defense modifiers por terreno + força da unidade
- **Atrito:** desert, arctic, marsh causam attrition
- **Logística:** supply lines via infraestrutura

### 3.4 Tech Tree (planejado)
Fonte: `TECH TREE - SR12.png` (árvore tecnológica de referência)
- Eras: 2025 → 2030+
- Categorias: militar, economia, social, ciência
- Pré-requisitos em árvore (não paralela)
- Efeito: desbloqueia unidades, edifícios, bonificações

### 3.5 Eventos (planejado)
Fonte: `Leaders2020.csv`, `World2030.OOF`
- Eventos por data (eventtime)
- Eventos condicionais (relações, região, nação)
- Eventos persistentes vs. one-shot
- Escolhas do jogador com consequências

### 3.6 Construção (planejado)
- Edifícios por província: fábricas, bases militares, infraestrutura, refinarias
- População por província (TODO: atualmente sempre 0 — bug a corrigir)
- Infraestrutura afeta movement_cost e supply

---

## 4. Modelo de Dados

### Hierarquia
```
World
├── HexGrid (320×200 cells)
│   └── HexCell (cada hexágono)
│       ├── terrain: int (0-12)
│       ├── elevation: float
│       ├── province_id: int
│       ├── owner_nation_id: int
│       ├── resource_type: int, resource_amount: int
│       ├── is_river: bool, flow_accumulation: int
│       └── population, infrastructure (TODO)
├── Provinces (Dictionary)
│   └── ProvinceData
│       ├── hexes: Array[Vector3]
│       ├── nation_id: int
│       ├── capital_hex: Vector3
│       ├── is_coastal: bool
│       └── population, infrastructure (TODO)
└── Nations (Dictionary)
    └── NationData
        ├── id, name, color, tag
        ├── province_ids: Array[int]
        ├── treasury, gdp, population
        ├── resources: Dictionary (stockpiles)
        ├── resource_production, resource_consumption
        ├── trade_balance
        └── government_type, is_player
```

### Autoloads
- **EventBus:** sinais globais (hex_clicked, hex_hovered, game_tick, camera_moved, grid_status)
- **GameManager:** estado do jogo (tick, data, pausa, velocidade, player_nation_id)
- **Constants:** constantes do jogo (terrain types, palette map)

### Tick system
- 1 tick = 1 dia de jogo
- `GameManager._process_game_tick()` acumula delta time
- A cada tick: `EventBus.game_tick.emit(current_tick)`
- HexGrid conecta: `_on_game_tick` → EconomySystem.calculate_all → MarketSystem.process_trade → EconomySystem.apply_all

---

## 5. Sistema de Mapa

### Arquitetura
```
MainMap (Node2D)
├── Camera2D (CameraController.gd)
├── HexGrid (Node2D)
│   ├── _MapBaseDrawer (Node2D)
│   │   └── MultiMeshInstance2D (64k hex fills, 1 draw call)
│   └── _draw() — borders, rivers, hover (batched PackedVector2Array)
└── UI (CanvasLayer)
    ├── DebugOverlay
    └── MainHUD
```

### Performance (otimizada)
- **MultiMesh** para hex fills: 1 draw call para 64k hexágonos
- **Border caches** em `PackedVector2Array` + `draw_multiline`
- **Nation cells** pré-calculadas em `EconomySystem._build_nation_cells()`
- **Heightmap distance** via two-pass sweep (não 60 relaxation passes)
- **Geo lookup** via grid espacial rasterizado em `SR2030Loader`

### Coordenadas
- **Offset coords:** (col, row) — 0..319, 0..199
- **Cube coords:** (q, r, s) — sistema axial, q+r+s=0
- **Pixel coords:** `cube_to_pixel(cube, hex_size=10)` → Vector2

### Geração de mundo
1. `_setup_heightmap()` — carrega terrain.bmp, mapeia palette → terrain types
2. `_setup_moisture_noise()` — FastNoiseLite para fallback
3. `_load_terrain_colors()` — carrega terrain.json
4. `_generate_terrain()` — cria HexCell para cada célula
5. `_generate_provinces()` — flood-fill por seeds, merge de províncias pequenas
6. `_generate_nations()` — match cells → países via SR2030 geo_match
7. `_generate_rivers()` — flow accumulation por elevação
8. `_generate_resources()` — probabilístico por terreno
9. `_build_border_cache()` — pré-calcula bordas de província/nação/rios

---

## 6. Fontes de Dados

### Assets/data/
| Arquivo | Tamanho | Conteúdo |
|---------|---------|----------|
| `maps/terrain.bmp` | 11.6 MB | Mapa de terreno 5616×2160 (8bpp indexed, 256 cores) |
| `maps/provinces.bmp` | 34.7 MB | Mapa de províncias 5616×2160 (RGB) |
| `maps/rivers.bmp` | 11.6 MB | Mapa de rios 5616×2160 |
| `maps/earth_heightmap.png` | 72 KB | Heightmap 320×200 para elevação |
| `sr2030_regions.json` | 48.9 KB | 119 nações com id, tag, name, color, capital |
| `sr2030_geo_match.json` | 4.2 KB | Bounding boxes por país (col/row min/max) |
| `terrain.json` | 1.3 KB | 13 tipos de terreno com atributos |
| `province_names.json` | 0.8 KB | Nomes de províncias (prefixos, raízes, sufixos) |
| `nation_names.json` | 0.8 KB | Nomes de nações |
| `dialogue/example_event.json` | 0.3 KB | Exemplo de evento de diálogo |

### Dados de referência (em `C:\Jogos\Godot_...\`)
| Arquivo | Conteúdo | Status |
|---------|----------|--------|
| `terrain.txt` | Legenda da paleta (256 entradas → tipo) | Parseado em `Constants.PALETTE_MAP` |
| `Leaders2020.csv` | ~30.000 eventos scriptados | A importar |
| `Modern2020.csv` | Relações diplomáticas iniciais (DipRel, CivRel, BelliRel) | A importar |
| `World 2030 Regions.csv` | Configuração de cenário por região | A importar |
| `SW2030Regions.csv` | Cenário "Shattered World" | A importar |
| `World2030.OOF` | 30.357 unidades/objetos posicionados | A importar |
| `TECH TREE - SR12.png` | Árvore tecnológica | A documentar |
| `Terra.lua` etc. | Scripts Civ VI (referência de geração) | Referência |

---

## 7. Arquitetura Técnica

### Stack
- **Engine:** Godot 4.6.3 (mono, GL Compatibility)
- **Linguagem:** GDScript
- **Resolução base:** 1280×720
- **Render:** 2D (CanvasItem), MultiMesh para performance

### Estrutura de pastas
```
ProjetoZero/
├── assets/
│   └── data/
│       ├── maps/           # BMPs e PNGs do mapa
│       ├── dialogue/       # JSONs de eventos
│       └── *.json          # Dados de jogo
├── scenes/
│   ├── MainMap.tscn        # Cena principal
│   └── ui/                 # HUD, telas
├── scripts/
│   ├── core/               # EventBus, GameManager, Constants, StateMachine
│   ├── map/                # HexGrid, HexCell, geradores, loaders
│   ├── economy/            # EconomySystem, MarketSystem, Resources
│   ├── ui/                 # MainHUD, DebugOverlay, panels
│   ├── camera/             # CameraController
│   └── dialogue/           # DialoguePlayer, DialogueInterface
├── tools/                  # Scripts utilitários (PowerShell)
└── project.godot
```

### Padrões de código
- **RefCounted** para objetos de dados leves (HexCell, geradores)
- **Resource** para objetos persistidos (NationData, ProvinceData)
- **Static methods** em geradores (não instanciados)
- **Signals** via EventBus para comunicação desacoplada
- **Dictionary** com Vector3 como chave para cells (cube coords)
- **Packed*Array** para dados contíguos (border caches)

### Performance
- Target: 60 FPS em mid-range hardware
- Startup: < 3 segundos (após otimizações)
- Tick: < 16ms (EconomySystem + MarketSystem)
- Render: MultiMesh + draw_multiline (batched)

---

## 8. Roadmap

### Fase 0: Fundação (CONCLUÍDO)
- [x] Hex grid 320×200 funcional
- [x] 119 nações com geo_match
- [x] 13 tipos de terreno (palette-indexed de terrain.bmp)
- [x] Sistema econômico base (produção, cadeia, comércio)
- [x] Performance otimizada (MultiMesh, nation_cells, border caches)

### Fase 1: Estabilidade (PRÓXIMA)
- [ ] Corrigir bug: `ProvinceData.population` nunca é setado
- [ ] Importar relações diplomáticas de `Modern2020.csv`
- [ ] Implementar population growth por província
- [ ] Save/Load game state
- [ ] Importar `provinces.bmp` para fronteiras reais

### Fase 2: Diplomacia
- [ ] Sistema de relações (DipRel, CivRel, BelliRel)
- [ ] Tratados (aliança, não-agressão, comércio)
- [ ] Ações diplomáticas (declarar guerra, fazer paz, embargo)
- [ ] UI diplomática

### Fase 3: Militar
- [ ] Tipos de unidades (infantaria, blindados, aéreos, navais)
- [ ] Movimento no hex grid (A* com terrain movement_cost)
- [ ] Combate (attack/defense modifiers + força)
- [ ] Logística e supply lines
- [ ] UI militar

### Fase 4: Tech Tree
- [ ] Documentar tech tree de `TECH TREE - SR12.png`
- [ ] Implementar árvore com pré-requisitos
- [ ] Efeitos: desbloqueia unidades, edifícios, bonificações
- [ ] UI de tech tree

### Fase 5: Eventos
- [ ] Parser de `Leaders2020.csv` (30k eventos)
- [ ] Sistema de condições (relações, região, data)
- [ ] UI de eventos com escolhas
- [ ] Eventos encadeados

### Fase 6: Polish
- [ ] Som e música
- [ ] Tutorial
- [ ] Balanceamento
- [ ] Localização (PT-BR, EN)
- [ ] Export (Windows, Linux)

---

## Notas de Implementação

### Conversão de coordenadas
```
Longitude → col:  col = floor((lon + 180) / 360 * 320)
Latitude → row:   row = floor((90 - lat) / 180 * 200)
col → Longitude:  lon = (col / 320) * 360 - 180
row → Latitude:   lat = 90 - (row / 200) * 180
```

### Bugs conhecidos
- `ProvinceData.population` sempre 0 → `NationData.population` sempre 0 → consumo populacional usa `pop=1` (EconomySystem.gd:90)
- `NationData.is_player` forçado em `nid == 0` (NationGenerator.gd:122) — deveria usar seleção do jogador
- `earth_heightmap.png` carregado via `img.load()` — não funciona em export (deveria ser `load()` como resource)

### Decisões técnicas
- **Terrain de BMP, não PNG:** PNG perdeu a paleta 8bpp; BMP preserva os 256 índices
- **Downscale nearest-neighbour:** preserva índices de paleta (interpolar misturaria tipos)
- **Two-pass sweep para distância:** O(n) vs O(n×passes) do relaxamento original
- **MultiMesh para hex fills:** 1 draw call vs 64k draw_colored_polygon
- **Nation cells pré-calculadas:** elimina 7,6M iterações/tick no EconomySystem
