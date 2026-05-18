# 🎮 **COMMANDERS' DEFENSE**

## Itch.io stranica igre
https://mexa123.itch.io/commanders-defense

## O PROJEKTU
- Commanders' Defense je 2D side scroll multiplayer igrica između dva igrača gde je cilj da se uništi neprijateljska odbrambena kula.                          
- Oba igrača su naoružana pištoljem i puškom, a jedini način da se nanese šteta kuli/hangaru je da se neprijateljski igrač prvo eliminiše.

## Arhitektura
- Klijentska strana (Client) - Godot Game Engine  
  - Klijentska aplikacija će biti napravljena upotrebnom Godot Game Engine 4.5 upotrebom ugrađenog GDScript jezika, koji po sintaksi veoma liči na Python.   
  - Zadužena samo sa prikaz i prosleđivanje akcija koje je korisnik uradio.
- Serverska strana (Server) - Rust  
  - Programski jezik Rust će se koristiti za pokretanje servera. Sam server će biti jedini "izvor istine". Biće zadužen za sinhronizaciju igre između dva klijenta.  
  - Vodiće računa o (sklono promenama):  
  1. **GameStateModel**
   ```rust
   pub struct GameStateModel { //Interni model koji omogućava da Rapier2d biblioteka mapira i računa kolizije
      //Entiteti koji postoje na Godot sceni
      pub next_player_id: u32,
      pub players: HashMap<u32, Player>,
      pub address_to_players: HashMap<SocketAddr, u32>,
  
      pub next_bullet_id: u32,
      pub bullets: HashMap<u32, Bullet>,
  
      pub next_tower_id: u32,
      pub towers: HashMap<u32, Tower>,
      pub kill_feed: KillFeed,
  
      pub socket: Arc<UdpSocket>,
      pub level_loader: LevelLoader,
  
      pub time_to_reset: f32,
      pub is_game_finished: bool,
  
      //Neophodno kako bi Rapier2d biblioteka optimizovala i mogla da vrši neophodno računanje
      pub rigid_body_set: RigidBodySet,
      pub collider_set: ColliderSet,
      pub physics_pipeline: PhysicsPipeline,
      pub island_manager: IslandManager,
      pub broad_phase: DefaultBroadPhase,
      pub narrow_phase: NarrowPhase,
      pub impulse_joint_set: ImpulseJointSet,
      pub multibody_joint_set: MultibodyJointSet,
      pub ccd_solver: CCDSolver,
      pub integration_parameters: IntegrationParameters,
      pub char_controller: KinematicCharacterController,
      pub collision_send: Sender<CollisionEvent>,
      pub collision_recv: Receiver<CollisionEvent>,
     
      pub force_send: Sender<ContactForceEvent>,
      pub force_recv: Receiver<ContactForceEvent>,
     }
   ```
    2. **Player**
    ```rust
    pub struct Player {
        pub id: u32,
        pub nickname: String,
        pub body_handle: RigidBodyHandle, // Vodi računa o poziciji, brzini, gravitaciji... da ne bih morao ručno
        pub collider_handle: ColliderHandle, // Kolider koji se koristi kako bi se utvrdilo da li je nešto prošlo kroz igrača
        pub vertical_velocity: f32,
        pub is_on_ground: bool,
        pub hp: i32,
        pub facing_right: bool,
        pub respawn_timer: f32,
        pub last_processed_input_id: u32,
        pub mouse_angle: f32,
        pub current_gun: GunEnum,
        pub shoot_cooldown: f32,
        pub player_inventory: HashMap<WeaponType, Weapon>,
        pub is_reloading: bool,
        pub current_ammo: i16,
        pub tower_id: Option<u32>, // Ako je gameMode sa kulama
        pub last_seen: Instant
    }
    ```
    3. **Bullet**
    ```rust
    pub struct Bullet {
        pub id: u32,
        pub owner_id: u32,
        pub body_handle: RigidBodyHandle,
        pub damage: i32,
        pub angle: f32,
        pub gun: GunEnum,
    }
    ```
    4. **Tower**
    ```rust
      pub struct Tower {
          pub id: u32,
          pub owner_id: u32,
          pub position: [f32; 2], // Kule su uvek u istom položaju, moguća i kasnija zamena sa RigidBodyHandler-om
          pub hp: i32,
          pub collider_handle: ColliderHandle,
          pub can_be_damaged: bool,
          pub is_left_tower: bool
      }
    ```
    5. **ClientInput**
    ```rust
     #[derive(Serialize, Deserialize, Debug)]
      pub struct ClientInput {
      // Klijent šalje ovo svaki tick, na kraju svakog _proccess(delta) poziva
      pub input_id: u32, // Kako bi klijent znao da li treba da "ponovi" neke inpute ako ima kašnjenja
      pub move_left: bool,
      pub move_right: bool,
      pub jump: bool,
      pub shoot: bool,
      pub mouse_angle: f32,
      pub command: CommandEnum, 
      pub gun: GunEnum,
      pub bullet_spawn_position: Option<[f32; 2]>,
      pub nickname: Option<String>,
    }
    ```
    6. **GameState (odgovor ka klijentu)**
    ```rust
      #[derive(Serialize, Deserialize)]
      pub struct GameState {
          pub players: Vec<PlayerSnapshot>, // Šalje se vektor zbog manje količine podataka
          pub bullets: Vec<BulletSnapshot>,
          pub towers: Vec<TowerSnapshot>,
          pub kill_events: Vec<KillEvent>,
      }
    
      #[derive(Serialize, Deserialize)]
      pub struct PlayerSnapshot {
          pub id: u32,
          pub nickname: String,
          pub position: [f32; 2],
          pub hp: i32,
          pub facing_right: bool,
          pub is_on_ground: bool,
          pub respawn_timer: f32,
          pub last_processed_input_id: u32,
          pub mouse_angle: f32,
          pub gun: GunEnum,
          pub is_reloading: bool,
          pub current_ammo: i16,
      }

      #[derive(Serialize, Deserialize)]
      pub struct BulletSnapshot {
          pub id: u32,
          pub position: [f32; 2],
          pub owner_id: u32,
          pub angle: f32,
          pub gun: GunEnum,
      }
      
      #[derive(Serialize, Deserialize)]
      pub struct TowerSnapshot {
          pub id: u32,
          pub owner_id: u32,
          pub hp: i32,
          pub is_left_tower: bool,
      }
    ```
    

## Komunikacija
- Kako će server biti jedini izvor istine, sve što klijent dobije mora da tako i prikaže. 
- Za komunikaciju će se koristiti UdpSocket (UDP - protokol).  
- Iako je inicijalno bilo planirano da se koristi TCP protokol, za sam tok igre je ipak bolji UDP, jer se kod UDP-a ne čeka odgovor primaoca, što smanjuje lag.
- Mogući pristup je da će se TCP protokol koristiti kod login-a, ulaska u određeni lobi...
- Takođe, promenjeno je da se ne šalju JSON objekti između klijenta i servera već binarno, iz dva razloga:  
    1. JSON je "teži", jer se prenosi cela struktura samog JSON objekta, dok kod binarnog samo bajtovi.
    2. Bezbednije je prenositi binarno, jer se kod binarnog mora tačno znati veličina bajtova za podatak, striktno se mora pratiti redosled podataka i šta taj podatak predstavlja, kako bi se struktura rekonstruisala na klijentskoj/serverskoj strani, čime je teže varati u igrici.
- Server će svaki tick( delta ) da šalje GameState, izmenjen podacima koji klijenti šalju, nazad klijentima.

  ### Validacija kretanja i kolizija
    1. **Client-Side Prediction (Lokalno pomeranje)**
       - Kada korisnik pritisne taster za pomeranje "DESNO" (primer), klijentska strana neće čekati odgovor servera kako bi ažurirala poziciju, nego će to učiniti odmah, kako sam korisnik ne bi osetio blago kašnjenje dok čeka pravu poziciju sa servera.
       - Kada dobije odgovor, odnosno GameState i prave pozicije igrača, ako je razlika mala, prihvatiće se prediktivno kretanje, kako klijentu ne bi "seckala" igrica zbog male razlike u poziciji. U slučaju da je razlika velika, klijentska strana mora postaviti igrača na onu poziciju koju je odredio/sračunao server.
       - Na klijentskoj strani, nakon svakog tick-a, čuvaće se svi neobrađeni poslati inputi ka serveru, u slučaju da server kasni sa odgovorom. Ako se ID poslednjeg inputa koji je server sračunao ne poklapa sa ID-jem trenutnog inputa, klijent ponovo izvršava sve inpute koji imaju veći ID inputa od obrađenog.
       - Na klijentskoj strani će se koristiti Area2D i CollisionShape2D, kako bi se utvrdilo da li je igrač udario u zid/platformu ako postoji.
       - Upotrebom ugrađene metode lerp(), ažuriraće se pozicija protivnika, kako bi promena bila fluidna, i kako ne bi delovalo da se protivnički igrač teleportuje iz pozicije u poziciju.
       - Sami efekti, kao što su zvuk ili pogodak igrača, će se prikazati na klijentskoj strani, ali samo predviđanje ne sme da ažurira bitne atribute GameState unapred, kao što su HP protivničkog igrača ili kule sve dok se ne dobije odgovor servera.
    2. **Server Reconciliation (Autoritativna pozicija)**
       - Upotrebom biblioteke Rapier2d, za svaki tick, server će izračunati pravu poziciju igrača. Pored toga, računaće i kolizije, da li je u toku kretanja došlo do kolizije za zidom ili metkom i shodno sračunatom rezultatu ažuriraće se GameState.
       - Kako bi uopšte mogle da se računaju kolizije i položaj, potrebno je koristiti Collider objekat odgovarajućeg oblika, kako bi se "scena" na klijentskoj strani što bolje oslikala na serverskoj strani. Za predstavu igrača bi se koristio pravougaonik pozivom ColliderBuilder::cuboid() metode.
       - Ako dođe do kolizije sa metkom, pogođenom igraču iz trenutnog GameState, oduzeće se HP atribut u zavisnosti koliko štete nanosi sam metak. Kada je HP pogođenog igrača manji od 0, server beleži da je igrač eliminisan, i atributu respawn_timer dodeljuje vrednost koja označava koliko sekundi eliminisan korisnik nije u mogućnosti da upravlja svojim igračem.
       - Sve dok je respawn_timer veći od 0, server ignoriše ClientInput-e sa datog klijenta.
       - Metak se neće ponašati kao pravi objekat, već kao senzor. To znači, da kada metak prođe kroz igrača, desi se pogodak, ali se neće uračunati fizika nad igračem, već se samo skida određena količina HP-a.

## Alati/Biblioteke
- Tokio - biblioteka za asinhroni rad Rust servera, kako bi istovremeno mogao da opslužuje dva/više klijenata istovremeno, bez da drugi čekaju u redu.
- Rapier2d - biblioteka za fiziku, koja olakšava računanje pozicija i kolizija.
- Bincode - biblioteka koja omogućava serijalizaciju/deserijalizaciju struktura koje Rust prima od Godot klijenata i koje šalje nazad u binarnom obliku.
- PacketPeerUDP - omogućava komunikaciju između klijenata i servera. PacketPeerUDP.new() - kreira objekat u Godot-u koji omogućava komunikaciju sa serverom preko UDP protokola.
- Axum - biblioteka za rad sa REST API-jem.
## Programi i linkovi
- Sprite-ovi crtani pomoću: Piskel https://www.piskelapp.com/
- Pozadinska muzika (**Ti se samo usudi - Instrumentalna verzija - Neven Ilinčić** ) i usklađivanje zvukova: N-Track Studio 10 (Demo verzija) https://ntrack.com/digital-audio-workstation.php
- Zvuci skakanja, hover dugmeta, koračanja: Bxfr https://www.bfxr.net/
- Pucanj pištolja, puške i određeni delovi repetiranja su preuzeti sa sajta: https://pixabay.com/sound-effects/
## 

## Demo snimak
https://drive.google.com/file/d/1BDI3QFiZQsAV35Yh6FFjOrm7U0F_Q1S_/view?usp=sharing


## Proširenja za diplomski
  1. ### Mogućnost kreiranja naloga ( korisničkog imena i lozinke ) i prijavljivanja na taj nalog:  
  - Axum biblioteka u Rust-u je korišćena za REST API pozive.
  - Za trenutne potrebe, u bazi se čuva samo username (nickname), kako ne bi postojala dva igrača sa istim nazivom, i šifra igrača.
  - Generisanje JWT tokena. Kada se konektuje, klijent serveru šalje JWT token koji je generisan od strane servera kao dokaz da igrač zaista postoji u sistemu, a kada validira igrača, Rust server dodaje igrača u "partiju".
  2. ### Live Chat
  - Mogućnost razmene poruka između dva igrača tokom trajanja partije. Komunikacija se vrši putem WebSocket kanala.
  3. ### Dodatni "Game mode" - Free For All ( FFA )
  - Pored osnovne ideje o odbrani kula, postoji i FFA. Poeni se skupljaju eliminišući druge igrače. Pobednik je onaj igrač koji, ili ostane jedini konektovan u lobiju ili prvi sakupi neophodan broj eliminacija.
     
