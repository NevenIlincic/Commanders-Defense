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


    
     
