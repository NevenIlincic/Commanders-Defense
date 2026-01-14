# 🎮 **COMMANDERS' DEFENSE**

## O PROJEKTU
- Commanders' Defense je 2D side scroll multiplayer igrica između dva igrača gde je cilj da se uništi neprijateljska odbrambena kula.                          
- Oba igrača su naoružana pištoljem i puškom, a jedini način da se nanese šteta kuli je da se neprijateljski igrač prvo eliminiše.

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
      players: HashMap<u32, Player>,
      bullets: HashMap<u32, Bullet>,
      towers: HashMap<u32, Tower>,

     //Neophodno kako bi Rapier2d biblioteka optimizovala i mogla da vrši neophodno računanje
      rigid_body_set: RigidBodySet,
      collider_set: ColliderSet,
      physics_pipeline: PhysicsPipeline,
      island_manager: IslandManager,
      broad_phase: BroadPhase,
      narrow_phase: NarrowPhase,
      impulse_joint_set: ImpulseJointSet,
      multibody_joint_set: MultibodyJointSet,
      ccd_solver: CCDSolver,
      query_pipeline: QueryPipeline,
      integration_parameters: IntegrationParameters,
      char_controller: KinematicCharacterController,
     }
   ```
    2. **Player**
    ```rust
    pub struct Player {
        id: u32,
        body_handle: RigidBodyHandle, // Vodi računa o poziciji, brzini, gravitaciji... da ne bih morao ručno
        collider_handle: ColliderHandle, // Kolider koji se koristi kako bi se utvrdilo da li je nešto prošlo kroz igrača
        vertical_velocity: f32,
        is_on_ground: bool,
        hp: f32,
        facing_right: bool,
        respawn_timer: f32,
        last_input_id: u32
    }
    ```
    3. **Bullet**
    ```rust
    pub struct Bullet {
        id: u32,
        owner_id: u32,
        body_handle: RigidBodyHandle
    }
    ```
    4. **Tower**
    ```rust
      pub struct Tower {
          id: u32,
          position: [f32; 2], // Kule su uvek u istom položaju, moguća i kasnija zamena sa RigidBodyHandler-om
          hp: f32,
          collider_handle: ColliderHandle
      }
    ```
    5. **ClientInput**
    ```rust
      #[derive(Serialize, Deserialize)]
      pub struct ClientInput { // Klijent šalje ovo svaki tick, na kraju svakog _proccess(delta) poziva
          input_id: u32,   // Kako bi klijent znao da li treba da "ponovi" neke inpute ako ima kašnjenja
          move_left: bool,
          move_right: bool,
          jump: bool,
          shoot: bool,
          mouse_angle: f32
      }
    ```
    6. **GameState (odgovor ka klijentu)**
    ```rust
      #[derive(Serialize, Deserialize)]
      pub struct GameState {
          players: Vec<PlayerSnapshot>, // Šalje se vektor zbog manje količine podataka
          bullets: Vec<BulletSnapshot>,
          towers: Vec<TowerSnapshot>,
      }
    
      #[derive(Serialize, Deserialize)]
      pub struct PlayerSnapshot {
          id: u32,
          position: [f32; 2],
          hp: f32,
          facing_right: bool, 
          is_on_ground: bool,
          respawn_timer: f32,
          last_input_id: u32
      }

      #[derive(Serialize, Deserialize)]
      pub struct BulletSnapshot {
          id: u32,
          position: [f32; 2],
          angle: f32
      }
      
      #[derive(Serialize, Deserialize)]
      pub struct TowerSnapshot {
          id: u32,
          hp: f32,
      }
    ```
    

## Komunikacija
- Kako će server biti jedini izvor istine, sve što klijent dobije mora da tako i prikaže. 
- Za komunikaciju će se koristiti WebSocket (TCP - protokol).  
- Iako je UDP protokol koji se češće koristi u brzim multiplayer igrama, za ovaj projekat (igricu) je bitnije da se zna tačno stanje igre.  
  ( moguća izmena u zavisnosti kakav odziv bude )
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
- Serde - biblioteka koja omogućava serijalizaciju/deserijalizaciju struktura koje Rust prima od Godot klijenata i koje šalje nazad.
- Ugrađeni JSON objekti u Godot-u za slanje potrebnih podataka ka serveru (poziv JSON.stringify() metode ).
- WebSocket - omogućaca komunikaciju između klijenata i servera. WebSocketPeer.new() - kreira WebSocket objekat u Godot-u.

## Proširenja za diplomski
 Ako tema bude odobrena, i ako steknem uslov za pisanje diplomskog rada iz ovog predmeta, neka od mogućih proširenja su:
  1. ### Mogućnost kreiranja naloga ( korisničkog imena i lozinke ) i prijavljivanja na taj nalog:  
  - Spring Boot bi se koristio kao dodatan server, koji je zadužen za čuvanje podataka u PostgreSQL bazu ( samo korisničko ime i lozinka ).
  - Generisanje JWT tokena. Kada se konektuje, klijent bi prvo poslao Rust serveru JWT token koji je generisan od strane Spring Boot-a kao dokaz da igrač zaista postoji u sistemu, a kada validira igrača, Rust server dodaje igrača u "partiju".
  2. ### Live Chat
  - Mogućnost razmene poruka između dva igrača tokom trajanja partije. Za to bih koristio Redis kao brzi keš za privremeno čuvanje poruka.
  3. ### Dodatni "Game mode" - Free For All ( FFA )
  - Pored osnovne ideje o odbrani kula - FFA bi uključivao više od dva igrača. Poeni bi se skupljali eliminišući druge igrače.
     
