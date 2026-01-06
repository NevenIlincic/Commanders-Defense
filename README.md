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
  1. Igrač ( Player ) - id, position, current_action, current_weapon, facing_direction, HP, respawn_timer...
  2. Metak ( Bullet ) - id, owner_id, position, direction, speed, damage..
  3. Kula ( Tower ) - id, owner_id, position, HP
  4. Trenutno stanje ( GameState ) - HashMap<u32, Player>, HashMap<u32, Bullet>, HashMap<u32, Tower>
     - GameState će ujedino biti i odgovor koji server šalje klijentima.

## Komunikacija
- Kako će server biti jedini izvor istine, sve što klijent dobije mora da tako i prikaže. 
- Za komunikaciju će se koristiti WebSocket (TCP - protokol).  
- Iako je UDP protokol koji se češće koristi u brzim multiplayer igrama, za ovaj projekat (igricu) je bitnije da se zna tačno stanje igre.  
  ( moguća izmena u zavisnosti kakav odziv bude )
- Server će svaki tick( delta ) da šalje GameState, izmenjen podacima koji klijenti šalju, nazad klijentima.

## Alati/Biblioteke
- Tokio - biblioteka za asinhroni rad Rust servera, kako bi istovremeno mogao da opslužuje dva/više klijenata istovremeno, bez da drugi čekaju u redu.
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
     
