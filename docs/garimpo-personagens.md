# Personagens para baixar (garimpo do Sketchfab)

Gerado por `tools/garimpo_personagens.py`. **Todos com animação própria** — o
filtro que decide tudo: dos 16 já recebidos, **6 não têm esqueleto** e são
estátuas (não andam, não mexem o braço).

## Como usar

1. Baixe em **glTF**.
2. Largue os `.zip` na raiz do projeto.
3. `tools/receber_modelos.sh personagens`
4. `godot --headless --path . --editor --quit` (importa os arquivos novos)
5. `godot --headless --path . tools/preparar_personagens.tscn` (mede e cataloga)

Não precisa editar código: o menu de Personagem, o preview 3D, o save e o
verificador passam a cobrir os modelos novos sozinhos.

## A coluna "serve como"

NPC aparece **72 vezes na tela ao mesmo tempo**; jogador, uma. Por isso o corte
em 18 mil faces — é custo, não gosto. Modelo pesado e caprichado entra como
opção de jogador, onde o capricho aparece e o custo não multiplica.

## ATENÇÃO: fan art de franquia

Vários resultados são personagens de outras obras (Ada Wong, Mileena, Hestia,
Rem, Faputa, Tomoko). A licença CC-BY cobre **o modelo**, não o personagem — num
jogo que você pretende publicar, isso é risco jurídico de terceiros. Para
cenário/teste tudo bem; para publicar, prefira personagem original.

Licença **CC-BY**: uso comercial liberado, crédito obrigatório (o projeto já
gera `docs/creditos.md`).

# Personagens (homem) — 39 candidatos

39 com animacao propria, 39 rigados, 0 sem esqueleto

Baixe em **glTF**. O que tem animacao propria entra direto; o que so
e rigado precisa da UAL1 aplicada por cima (o esqueleto tem que bater,
conferir com tools/verify/analisar_realistas.tscn); o que nao tem
esqueleto NAO serve como jogavel sem passar pelo Blender.

| animações | faces | serve como | licença | modelo | autor |
|---|---|---|---|---|---|
| 1 | 21.506 | jogador | CC-BY | [Nathan Animated 003 - Walking 3D Man](https://sketchfab.com/3d-models/143a2b1ea5eb4385ae90a73657aca3bc) | Renderpeople |
| 1 | 25.434 | jogador | CC-BY | [.Fuse Woman 1](https://sketchfab.com/3d-models/c6436897da494b4e8e1f8188aea620c6) | Leonardo Carvalho |
| 1 | 22.025 | jogador | CC-BY | [.Fuse Civilian 1](https://sketchfab.com/3d-models/6fc4bddf4d364e6b9fa2f050011e03ce) | Leonardo Carvalho |
| 1 | 13.259 | jogador + NPC | CC-BY | [Security Guard – Rigged 3D Model](https://sketchfab.com/3d-models/1e3307732bbf4453b30f021bfec5bcaf) | Q.SARDOR |
| 1 | 2.469 | jogador + NPC | CC-BY | [Girl with clothes. Worker set](https://sketchfab.com/3d-models/4cf10e2dde6d4b12b6dccd25a4cf3b77) | cattleya |
| 1 | 53.891 | jogador | CC-BY | [Realistic Old Russian Guy (animated)](https://sketchfab.com/3d-models/6b8009a6e4f747f59ccadb121adc3679) | Jungle Jim |
| 1 | 31.323 | jogador | CC-BY | [Man In Coat - Human Rigged Model](https://sketchfab.com/3d-models/cd71038373d5427099a7970f1a1af2df) | Saitam |
| 1 | 20.939 | jogador | CC-BY | [old man in coat - human riged model](https://sketchfab.com/3d-models/e8052f5928ef42f1ae5b5af02eb1a36b) | Kasit Studio |
| 1 | 110.940 | jogador | CC-BY | [Balthazar (rigged & animated)](https://sketchfab.com/3d-models/dbf9fe0cb81d4758ad2525a56d10e2fc) | Jungle Jim |
| 20 | 5.176 | jogador + NPC | CC-BY | [Low Poly Game Character Skins [ PACK / RIGGED]](https://sketchfab.com/3d-models/c23ffc918c7e4703aa13ec4abe9bfd4b) | micaelsampaio |
| 23 | 179.421 | jogador | CC-BY | [King Kong animated](https://sketchfab.com/3d-models/2b7ce05ebe4c47178b30e18dd334ede5) | Make Joke Horror Official |
| 1 | 41.407 | jogador | CC-BY | [Mr Man Walking](https://sketchfab.com/3d-models/98ccac2b0e2845789b6f789978ca06ed) | Instinto Ideal Studio |
| 1 | 105.084 | jogador | CC-BY | [Anime_Girl_Character_Free_GameReady_Animated](https://sketchfab.com/3d-models/b8e1967c0703492e8121d9457f056d27) | RahulTambat |
| 1 | 4.384 | jogador + NPC | CC-BY | [Low Poly Female](https://sketchfab.com/3d-models/07eeb124d210402bbc061e543d0b97a1) | Loves_Art |
| 1 | 130.778 | jogador | CC-BY | [Proletheus (animated character)](https://sketchfab.com/3d-models/31662c5ba7f54b66974780f0466124a7) | Jungle Jim |
| 9 | 148.980 | jogador | CC-BY | [Rem - Re:Zero](https://sketchfab.com/3d-models/0b1cf5f86db3455f9087ae476cd28864) | DarienToad |
| 1 | 4.090 | jogador + NPC | CC-BY | [Low Poly Male](https://sketchfab.com/3d-models/7d601a034c1c45e68151bddf386e48b3) | Loves_Art |
| 2 | 25.098 | jogador | CC-BY | [Old fat man character full rig](https://sketchfab.com/3d-models/d4138985fb2f4a7e8751ca744eac49ea) | David Glynch |
| 9 | 12.545 | jogador + NPC | CC-BY | [Monkey D. Luffy](https://sketchfab.com/3d-models/3d9fb8bd86854aa69ee6f69fcbeaca51) | nitwit.friends |
| 1 | 170.905 | jogador | CC-BY | [Old man Spice (animated)](https://sketchfab.com/3d-models/abe7334fe40b48879155c3ecea3805cb) | Jungle Jim |
| 1 | 165.858 | jogador | CC-BY | [Ada Wong Rigged](https://sketchfab.com/3d-models/dad5960938e447fe8c88b8bdf02e4702) | Ar3Designer |
| 1 | 3.128 | jogador + NPC | CC-BY | [Low-poly Construction workers (animated)](https://sketchfab.com/3d-models/b026b514c7254f399238b22a1f94fe0a) | Jungle Jim |
| 1 | 10.962 | jogador + NPC | CC-BY | [Casual Man Character](https://sketchfab.com/3d-models/05d9dd5bdddd4157bd46dc179781ee6e) | Bogdan Strielecki |
| 1 | 60.410 | jogador | CC-BY | [Background People for Blender promo / Animated](https://sketchfab.com/3d-models/ee74d352e49347658dd8675ffebf13eb) | Jungle Jim |
| 1 | 17.208 | jogador + NPC | CC-BY | [Larva Man-walking](https://sketchfab.com/3d-models/9adba5a3a0e54563b42d62c6f2330bf2) | H.art |
| 11 | 3.296 | jogador + NPC | CC-BY | [Low poly ordinary man in shirt and pants](https://sketchfab.com/3d-models/f658b9e1bb324f2ab1e9f00d7d6b4065) | Agor_2012 |
| 1 | 23.678 | jogador | CC-BY | [Frank - Army man](https://sketchfab.com/3d-models/956292ef483d490695867d6601fe423b) | TrevAllCaps |
| 1 | 61.952 | jogador | CC-BY | [Animated Man-Run and Jump Character](https://sketchfab.com/3d-models/7045943fe9654fab8200359b28e7982b) | 3DStuff |
| 1 | 54.712 | jogador | CC-BY | [teen-boy](https://sketchfab.com/3d-models/fff65cd5b0934eff8e3a281766a52bf5) | theskipper |
| 1 | 74.990 | jogador | CC-BY | [Lego Man Walking](https://sketchfab.com/3d-models/2fb8cf2ceebf4ae799bcfa3745e0e9d8) | KageG |
| 1 | 26.748 | jogador | CC-BY | [Male Character Base - Rigged](https://sketchfab.com/3d-models/83d91cbfe6fd48ad87f3a2264d3bcb47) | Braingapps |
| 1 | 10.400 | jogador + NPC | CC-BY | [Among Us Red w/Animation](https://sketchfab.com/3d-models/c3dddcce6cb2470aadc97f2652411254) | LOLKing |
| 1 | 48.994 | jogador | CC-BY | [Nick (African) - Scary Teacher 3D (Rigged)](https://sketchfab.com/3d-models/63d916bfee084be097a9359897a7ab44) | Villanueva-Jonatan-32621 |
| 2 | 97.548 | jogador | CC-BY | [Ojamnbek - Idle + Walk Cycle](https://sketchfab.com/3d-models/ca69f89bef684fb08648ef7afde60386) | Lotussai |
| 1 | 59.895 | jogador | CC-BY | [Bob Bobalino (Animated)](https://sketchfab.com/3d-models/df722667b7d346e4ae4b98f4b8b5455b) | Jungle Jim |
| 1 | 25.995 | jogador | CC-BY | [Bob (Player) - Scary Stranger 3D](https://sketchfab.com/3d-models/c6dd506e584e44eb9f77d2cfda88b6dd) | Villanueva-Jonatan-32621 |
| 5 | 108.530 | jogador | CC-BY | [Stylized Character](https://sketchfab.com/3d-models/da8d7682e07248569bfc2d0d7969be92) | WisherZard |
| 1 | 14.441 | jogador + NPC | CC-BY | [Nick (Stone Age) - Scary Teacher 3D (Rigged)](https://sketchfab.com/3d-models/b9f0d94c07034ffa9bc5b009df749636) | Villanueva-Jonatan-32621 |
| 1 | 17.898 | jogador + NPC | CC-BY | [Humanoids](https://sketchfab.com/3d-models/e251dab5e4a34a56893109069a0731fe) | sameer |

---

# Personagens (mulher) — 41 candidatos

41 com animacao propria, 41 rigados, 0 sem esqueleto

Baixe em **glTF**. O que tem animacao propria entra direto; o que so
e rigado precisa da UAL1 aplicada por cima (o esqueleto tem que bater,
conferir com tools/verify/analisar_realistas.tscn); o que nao tem
esqueleto NAO serve como jogavel sem passar pelo Blender.

| animações | faces | serve como | licença | modelo | autor |
|---|---|---|---|---|---|
| 1 | 156.440 | jogador | CC-BY | [Kindred (League of Legends) - Rigged](https://sketchfab.com/3d-models/06a32da82b0441c39950296315307400) | maisth |
| 1 | 49.788 | jogador | CC-BY | [Miss Galaxy](https://sketchfab.com/3d-models/32ca79bf7c4043dcbc36d28b22436303) | Loves_Art |
| 1 | 22.360 | jogador | CC-BY | [Free Download - Chobby Bun ヽ(‘ ∇‘ )ノ](https://sketchfab.com/3d-models/af9401a3403a425eae680924e8daef79) | Bom39 |
| 1 | 137.654 | jogador | CC-BY | [Alina Ip, realistic Asian woman (Animated)](https://sketchfab.com/3d-models/600d4d4aa71c4181b2567a3605ce8c57) | Jungle Jim |
| 3 | 82.544 | jogador | CC-BY | [Tomoko Kuroki / Watamote](https://sketchfab.com/3d-models/1653d538ffc445ce89e7b465271a8929) | DimitriyArts |
| 15 | 81.908 | jogador | CC-BY | [Chibi Rem - Confession](https://sketchfab.com/3d-models/5d78063c31a84229b9fba468a0993844) | Lemon Leon |
| 1 | 64.539 | jogador | CC-BY | [Faputa =Made in Abyss= [animatable]](https://sketchfab.com/3d-models/bf23cc901cad47e18bb12bfa2d4a37a7) | kopsinz |
| 20 | 77.004 | jogador | CC-BY | [Topology Practice: (ft. JoseDiaz)](https://sketchfab.com/3d-models/6752fe49b0914f3db3120252ac12f965) | noahm1216 |
| 1 | 128.026 | jogador | CC-BY | [Ghost Girl Animated](https://sketchfab.com/3d-models/1091b3ee172f4951aaeafa2581f9de1d) | Shaban Hafizsalim |
| 1 | 25.434 | jogador | CC-BY | [.Fuse Woman 1](https://sketchfab.com/3d-models/c6436897da494b4e8e1f8188aea620c6) | Leonardo Carvalho |
| 1 | 199.960 | jogador | CC-BY | [DanMachi- ダンまち - Hestia](https://sketchfab.com/3d-models/006a9e4038c54028898e44ed5bc51447) | Kaijin |
| 1 | 72.951 | jogador | CC-BY | [Reze – Stylized Anime Girl](https://sketchfab.com/3d-models/f1d8f9a207554a5cba21e9e8516273f4) | bolbi601 |
| 1 | 2.469 | jogador + NPC | CC-BY | [Girl with clothes. Worker set](https://sketchfab.com/3d-models/4cf10e2dde6d4b12b6dccd25a4cf3b77) | cattleya |
| 3 | 23.300 | jogador | CC-BY | [Game character, Girl. Rigged, textured, animated](https://sketchfab.com/3d-models/e304748a4d704299bb1c37bb6f8cf40e) | gbarzu |
| 1 | 40.848 | jogador | CC-BY | [Musha, a cute girl can disguise as mushroom](https://sketchfab.com/3d-models/271a9fc752da44659810cd11fbf48be9) | ChamberSu |
| 1 | 92.084 | jogador | CC-BY | [Shang Hai Style Lady in glasses](https://sketchfab.com/3d-models/2e4260a3cdd5402f954ed2d932536e7d) | aribb |
| 20 | 5.176 | jogador + NPC | CC-BY | [Low Poly Game Character Skins [ PACK / RIGGED]](https://sketchfab.com/3d-models/c23ffc918c7e4703aa13ec4abe9bfd4b) | micaelsampaio |
| 1 | 6.602 | jogador + NPC | CC-BY | [character girl animated walk](https://sketchfab.com/3d-models/266d11aace6843809d62a1a3ceb9876a) | Unity  (shehab house) |
| 1 | 105.084 | jogador | CC-BY | [Anime_Girl_Character_Free_GameReady_Animated](https://sketchfab.com/3d-models/b8e1967c0703492e8121d9457f056d27) | RahulTambat |
| 1 | 15.476 | jogador + NPC | CC-BY | [Mortal Kombat Mileena](https://sketchfab.com/3d-models/afdb4d99392848c790257fecce670e62) | Anatolii Rogoznikov |
| 1 | 11.790 | jogador + NPC | CC-BY | [Bunny Set pubg](https://sketchfab.com/3d-models/9e434bc652144c57bde07269fd8a63a2) | instagram1m_lal |
| 1 | 4.384 | jogador + NPC | CC-BY | [Low Poly Female](https://sketchfab.com/3d-models/07eeb124d210402bbc061e543d0b97a1) | Loves_Art |
| 2 | 9.760 | jogador + NPC | CC-BY | [Low-poly female - Lia](https://sketchfab.com/3d-models/c1f44b8560bb40f3b266374b55ba4d32) | vappex |
| 1 | 5.778 | jogador + NPC | CC-BY | [Beka - Low-poly character](https://sketchfab.com/3d-models/41f153b386524655998996966d5f68eb) | vappex |
| 1 | 4.090 | jogador + NPC | CC-BY | [Low Poly Male](https://sketchfab.com/3d-models/7d601a034c1c45e68151bddf386e48b3) | Loves_Art |
| 1 | 2.046 | jogador + NPC | CC-BY | [Low-poly Girl](https://sketchfab.com/3d-models/3e79fef9da5f4db7b6a46f3e0ff89328) | Razvan Savescu |
| 1 | 6.582 | jogador + NPC | CC-BY | [Kim. low poly character](https://sketchfab.com/3d-models/54a65f4408314f26a442b0e0084a2375) | ukrwebprom |
| 7 | 29.380 | jogador | CC-BY | [SWIPE](https://sketchfab.com/3d-models/799ce3c4507241d2845fb243ea429361) | SomeDude |
| 1 | 165.858 | jogador | CC-BY | [Ada Wong Rigged](https://sketchfab.com/3d-models/dad5960938e447fe8c88b8bdf02e4702) | Ar3Designer |
| 3 | 2.564 | jogador + NPC | CC-BY | [Low-poly Woman](https://sketchfab.com/3d-models/752778128b9a4b578586dbce40c0366f) | Razvan Savescu |
| 1 | 60.410 | jogador | CC-BY | [Background People for Blender promo / Animated](https://sketchfab.com/3d-models/ee74d352e49347658dd8675ffebf13eb) | Jungle Jim |
| 1 | 12.352 | jogador + NPC | CC-BY | [Nilda Female Character Walk Animation](https://sketchfab.com/3d-models/d3f65ad04ec845b197a689db48ec4329) | ijiklvn |
| 3 | 6.920 | jogador + NPC | CC-BY | [Cute Chibi Girl - Free Game-Ready Character](https://sketchfab.com/3d-models/28e2f98ab4bf4313a3f258d45d987716) | Yury Misiyuk |
| 1 | 6.498 | jogador + NPC | CC-BY | [Casual NPC Woman / Free Low-Poly 3D Model](https://sketchfab.com/3d-models/48902da4e3f8494b80e349a3cb819385) | Stan |
| 1 | 54.686 | jogador | CC-BY | [Konnyaku](https://sketchfab.com/3d-models/2c25f4bcacb043a397b1f505c1149402) | Artical |
| 2 | 128.311 | jogador | CC-BY | [Anime Lowpoly Character](https://sketchfab.com/3d-models/a2842bf62a3a4a639ed7d356ccb54d56) | happybohra709 |
| 1 | 255.948 | jogador | CC-BY | [Casual Woman in Brown Dress Rigged Idle](https://sketchfab.com/3d-models/b38456c89bf94323aa3c079f27e435ce) | florah |
| 1 | 207.436 | jogador | CC-BY | [Rigged Standing Asian Female Character Idle Pose](https://sketchfab.com/3d-models/b31b024797194829af4637fbfb6838b7) | florah |
| 1 | 79.273 | jogador | CC-BY | [Bloody Scarlet](https://sketchfab.com/3d-models/9cdedb97b8614d1381b8e4535d7ffb67) | Ali_Sha |
| 1 | 99.045 | jogador | CC-BY | [Everyday Jane, Casual modern woman, rigged](https://sketchfab.com/3d-models/4c32c738e0074637beac26bbe670aca3) | XRProfXR |
| 1 | 32.432 | jogador | CC-BY | [TakeoffBackpackWoman2](https://sketchfab.com/3d-models/aee7988a2bbe4550b7625b1a60ab2ce9) | Berkan35 |
