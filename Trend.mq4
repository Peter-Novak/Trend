/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* Trend.mq4, verzija: 1, julij 2016                                                                                                                                                      *
*                                                                                                                                                                                      *
* Copyright Peter Novak ml., M.Sc.                                                                                                                                                     *
****************************************************************************************************************************************************************************************
*/

#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"



// Vhodni parametri --------------------------------------------------------------------------------------------------------------------------------------------------------------------
extern double d;                     // Razdalja od črte indikatorja do ravni za nakup ali prodajo;
extern double L;                     // Velikost pozicij v lotih;
extern double p;                     // profitni cilj za prvi dve tretjini pozicij;
extern int    samodejniPonovniZagon; // Samodejni ponovni zagon - DA(>0) ali NE(0). Če je vrednost DA, se algoritem po zaključeni transakciji ponovno štarta, sicer ne.
extern int    n;                     // Številka iteracije. Če želimo zagon nove iteracije, potem podamo vrednost 0;
extern double odmikSL;               // Odmik pri postavljanju stop-loss na break-even. Vrednost odmika prištejemo (buy) ali odštejemo (sell) ceni odprtja;



// Globalne konstante ------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define NEVELJAVNO -3   // oznaka za vrednost spremenljivk braven / sraven;
#define USPEH      -4   // oznaka za povratno vrednost pri uspešno izvedenem klicu funkcije;
#define NAPAKA     -5   // oznaka za povratno vrednost pri neuspešno izvedenem klicu funkcije;
#define NAD        -1   // cena nad črto indikatorja
#define POD        -2   // cena pod črto indikatorja 
#define ODPRTO     -6   // trgovanje je odprto
#define ZAPRTO     -7   // trgovanje je zaprto
#define S0          1   // oznaka za stanje S0 - Čakanje na zagon;
#define S1          2   // oznaka za stanje S1 - Nakup;
#define S2          3   // oznaka za stanje S2 - Prodaja;
#define S3          4   // oznaka za stanje S3 - Zaključek;



// Globalne spremenljivke --------------------------------------------------------------------------------------------------------------------------------------------------------------
int    bpozicija1;        // Enolična oznaka 1. dela odprte nakupne pozicije. Če ne obstaja, potem ima vrednost NEVELJAVNO;
int    bpozicija2;        // Enolična oznaka 2. dela odprte nakupne pozicije. Če ne obstaja, potem ima vrednost NEVELJAVNO;
int    spozicija1;        // Enolična oznaka 1. dela odprte prodajne pozicije. Če ne obstaja, potem ima vrednost NEVELJAVNO;
int    spozicija2;        // Enolična oznaka 1. dela odprte prodajne pozicije. Če ne obstaja, potem ima vrednost NEVELJAVNO;
int    stanje;            // Trenutno stanje algoritma;
int    zacetnaPozicija;   // ali smo začeli nad ali pod črto indikatorja;
int    trgovanje;         // indikator ali je trgovanje odprto ali zaprto;
int    stevilkaIteracije; // Številka trenutne iteracije;
int    verzija = 1;       // Trenutna verzija algoritma;



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* GLAVNI PROGRAM in obvezne funkcije: init, deinit, start                                                                                                                              *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: deinit  
----------------
(o) Funkcionalnost: Sistem jo pokliče ob zaustavitvi. M5 je ne uporablja
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/   
int deinit()
{
  return( USPEH );
} // deinit 



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: init  
--------------
(o) Funkcionalnost: Sistem jo pokliče ob zagonu. V njej izvedemo naslednje:
  (-) izpišemo pozdravno sporočilo
  (-) pokličemo funkcije, ki ponastavijo vse ključne podatkovne strukture algoritma na začetne vrednosti
  (-) začnemo novo iteracijo algoritma, če je podana številka iteracije 0 ali vzpostavimo stanje algoritma glede na podano številko iteracije 
(o) Zaloga vrednosti: USPEH, NAPAKA
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int init()
{
  bool rezultat; // spremenljivka, ki hrani povratno informacijo ali je prišlo do napake pri branju podatkov iz datoteke
    
  IzpisiPozdravnoSporocilo();
  
  // ------------------ Blok za klice servisnih funkcij - na koncu odkomentiraj vrstico, ki pošlje algoritem v stanje S4.---------------------
  // ---sem vstavi klice servisnih funkcij - primer:
  // PrepisiZapisIteracije( 11200, 0.00100, 0.00100, 1.08772, 0.09, 0.00100, 0, 0.00010, "M5-11200-kopija-2.dat" );
  // PrepisiZapisIteracije( 11100, 0.00100, 0.00100, 1.08926, 0.08, 0.00100, 0, 0.00010, "M5-11100-kopija-2.dat" );
  // stanje = S4; samodejniPonovniZagon = 0; return( USPEH );
  // ------------------ Konec bloka za klice servisnih funkcij -------------------------------------------------------------------------------
  
  if( Bid >= CenaIndikatorja() ) { zacetnaPozicija = NAD; } else { zacetnaPozicija = POD; };
  
  if( n == 0 ) // Številka iteracije ni podana - začnemo novo iteracijo
  { 
    PonastaviVrednostiPodatkovnihStruktur();
    stevilkaIteracije = OdpriNovoIteracijo();
    if( stevilkaIteracije == NAPAKA ) 
      { Print( "Trend-", verzija, ":init:USODNA NAPAKA: pridobivanje številke iteracije ni uspelo. Delovanje ustavljeno." ); stanje = S3; samodejniPonovniZagon = 0; return( NAPAKA ); }
      else                           
      { 
        Print( "Trend-", verzija, ":init:Odprta nova iteracija št. ", stevilkaIteracije ); n = stevilkaIteracije; 
        ShraniIteracijo( stevilkaIteracije ); stanje = S0; return( USPEH ); 
      }
  }
  else         // Številka iteracije je podana - nadaljujemo z obstoječo iteracijo
  {
    stevilkaIteracije = n;
    rezultat          = PreberiIteracijo( stevilkaIteracije ); 
    if( rezultat == NAPAKA ) { Print( "Trend-", verzija, ":init:USODNA NAPAKA: branje iteracije ni uspelo. Delovanje ustavljeno." ); stanje = S3; return( NAPAKA ); }
    stanje            = IzracunajStanje(); 
    if( stanje   != NAPAKA ) { return( USPEH ); }
    else                     { Print( "Trend-", verzija, ":init:USODNA NAPAKA: izračun stanja algoritma ni uspel. Delovanje ustavljeno." ); stanje = S3; return( NAPAKA ); }                                                                                                       
  }
  Print( "Trend-", verzija, ":init:OPOZORILO: ta stavek se ne bi smel izvršiti - preveri pravilnost delovanja algoritma" );
  return( USPEH );
} // init



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: start  
---------------
(o) Funkcionalnost: Glavna funkcija, ki upravlja celoten algoritem - sistem jo pokliče ob vsakem ticku. 
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int start()
{
  int trenutnoStanje; // zabeležimo za ugotavljanje spremebe stanja
 
  trenutnoStanje = stanje;
  switch( stanje )
  {
    case S0: stanje = S0CakanjeNaZagon(); break;
    case S1: stanje = S1Nakup();          break;
    case S2: stanje = S2Prodaja();        break;
    case S3: stanje = S3Zakljucek();      break;
    default: Print( "Trend-", verzija, ":[", stevilkaIteracije, "]:", ":start:OPOZORILO: Stanje ", stanje, " ni veljavno stanje - preveri pravilnost delovanja algoritma." );
  }
  // če je prišlo do prehoda med stanji izpišemo obvestilo
  if( trenutnoStanje != stanje ) { Print( ":[", stevilkaIteracije, "]:", "Prehod: ", ImeStanja( trenutnoStanje ), " ===========>>>>> ", ImeStanja( stanje ) ); }

  // osveževanje ključnih kazalnikov delovanja algoritma na zaslonu
  Comment( "Številka iteracije: ", stevilkaIteracije, " \n", "Stanje: ", ImeStanja( trenutnoStanje ) );
  
  return( USPEH );
} // start



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* POMOŽNE FUNKCIJE                                                                                                                                                                     *
* Urejene po abecednem vrstnem redu                                                                                                                                                    *
****************************************************************************************************************************************************************************************
*/



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: CenaIndikatorja()
-------------------------------------
(o) Funkcionalnost: Vrne trenutno vrednost indikatorja supertrend.  
(o) Zaloga vrednosti: cena
(o) Vhodni parametri: / 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string CenaIndikatorja()
{
  // dopolni logiko za izračun vrednosti indikatorja
} // CenaIndikatorja


/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ImeStanja( int KodaStanja )
-------------------------------------
(o) Funkcionalnost: Na podlagi numerične kode stanja, vrne opis stanja.  
(o) Zaloga vrednosti: imena stanj
(o) Vhodni parametri: KodaStanja: enolična oznaka stanja. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string ImeStanja( int KodaStanja )
{
  switch( KodaStanja )
  {
    case S0: return( "S0 - ČAKANJE NA ZAGON" );
    case S1: return( "S1 - NAKUP"            );
    case S2: return( "S2 - PRODAJA"          );
    case S3: return( "S3 - ZAKLJUČEK"        );
    default: Print ( "Trend-", verzija, ":[", stevilkaIteracije, "]:", ":ImeStanja:OPOZORILO: Koda stanja ", KodaStanja, " ni prepoznana. Preveri pravilnost delovanja algoritma." );
  }
  return( NAPAKA );
} // ImeStanja



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzpisiPozdravnoSporocilo
----------------------------------
(o) Funkcionalnost: izpiše pozdravno sporočilo, ki vsebuje tudi verzijo algoritma
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzpisiPozdravnoSporocilo()
{
  Print( "****************************************************************************************************************" );
  Print( "Dober dan. Tukaj Trend, verzija ", verzija, "." );
  Print( "****************************************************************************************************************" );
  return( USPEH );
} // IzpisiPozdravnoSporocilo

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzracunajStanje
-------------------------
(o) Funkcionalnost: glede na trenutno stanje podatkovnih struktur algoritma in trenutno ceno valutnega para (Bid) izračuna stanje algoritma
(o) Zaloga vrednosti: 
 (-) če je bilo stanje algoritma mogoče izračunati, potem vrne kodo stanja
 (-) NAPAKA: stanja ni bilo mogoče izračunati
(o) Vhodni parametri: / - uporablja globalne podatkovne strukture
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
IzpolnjenPogojzaBE( spozicija1 ) == true



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzracunajStanje
-------------------------
(o) Funkcionalnost: glede na trenutno stanje podatkovnih struktur algoritma in trenutno ceno valutnega para (Bid) izračuna stanje algoritma
(o) Zaloga vrednosti: 
 (-) če je bilo stanje algoritma mogoče izračunati, potem vrne kodo stanja
 (-) NAPAKA: stanja ni bilo mogoče izračunati
(o) Vhodni parametri: / - uporablja globalne podatkovne strukture
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzracunajStanje()
{
  double c; // cena indikatorja
 
  c = CenaIndikatorja();
  if( Bid >= c )                                    // ali smo nad črto ali pod črto?
  {
    if( bpozicija == NEVELJAVNO ) { zacetnaPozicija = NAD; trgovanje = ZAPRTO; return( S0 ); } // nad črto in brez odprte pozicije
    else                          { return( S1 ); } // nad črto, nakup
  }
  else
  {
    if( spozicija == NEVELJAVNO ) { zacetnaPozicija = POD; trgovanje = ZAPRTO; return( S0 ); } // pod črto in brez odprte pozicije
    else                          { return( S2 ); } // pod črto, prodaja
  }
} // IzracunajStanje



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriNovoIteracijo
----------------------------
(o) Funkcionalnost: 
  (-) preveri ali globalna spremenljivka TrendIteracija obstaja
  (-) če obstaja, potem prebere njeno vrednost, jo poveča za 1, shrani nazaj in shranjeno vrednost vrne kot številko iteracije
  (-) če ne obstaja, potem jo ustvari, nastavi njeno vrednost na 1 in vrne 1 kot številko iteracije
(o) Zaloga vrednosti:
  (-) številka iteracije, če ni bilo napake
  (-) NAPAKA, če je pri branju ali pisanju v globalno spremenljivko prišlo do napake
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriNovoIteracijo()
{
  double   i;        // hramba za trenutno vrednost iteracije
  datetime rezultat; // hramba za rezultat nastavljanja globalne spremenljivke M5Iteracija

  if( GlobalVariableCheck( "TrendIteracija" ) == true ) { i = GlobalVariableGet( "TrendIteracija" ); i = i + 1; } else { i = 1; }
  rezultat = GlobalVariableSet( "TrendIteracija", i );
  if( rezultat == 0 ) { Print( "Trend-", verzija, ":OdpriNovoIteracijo:NAPAKA: Pri shranjevanju številke iteracije ", i, " je prišlo do napake." ); return( NAPAKA ); }
  return( i );
} // OdpriNovoIteracijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriPozicijo( int Smer, double v, double sl, double tp )
----------------------------------------------------
(o) Funkcionalnost: Odpre pozicijo po trenutni tržni ceni v podani Smeri in nastavi stop loss na podano ceno
(o) Zaloga vrednosti: ID odprte pozicije;
(o) Vhodni parametri:
 (-) Smer: OP_BUY ali OP_SELL
 (-) v: velikost pozicije
 (-) sl: cena za stop loss
 (-) tp: cena za take profit
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriPozicijo( int Smer, double v, double sl, double tp )
{
  int rezultat;    // spremenljivka, ki hrani rezultat odpiranja pozicije
  int magicNumber; // spremenljivka, ki hrani magic number pozicije
  string komentar; // spremenljivka, ki hrani komentar za pozicijo
 
  magicNumber = stevilkaIteracije;
  komentar    = StringConcatenate( "TR", verzija, "-", stevilkaIteracije );

  do
    {
      if( Smer == OP_BUY ) { rezultat = OrderSend( Symbol(), OP_BUY,  v, Ask, 0, sl, tp, komentar, magicNumber, 0, Green ); }
      else                 { rezultat = OrderSend( Symbol(), OP_SELL, v, Bid, 0, sl, tp, komentar, magicNumber, 0, Red   ); }
      if( rezultat == -1 ) 
        { 
          Print( "Trend-", verzija, ":[", stevilkaIteracije, "]:", ":OdpriPozicijo:NAPAKA: neuspešno odpiranje pozicije. Ponoven poskus čez 30s..." ); 
          Sleep( 30000 );
          RefreshRates();
        }
    }
  while( rezultat == -1 );
  return( rezultat );
} // OdpriPozicijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PonastaviVrednostiPodatkovnihStruktur
-----------------------------------------------
(o) Funkcionalnost: Funkcija nastavi vrednosti vseh globalnih spremenljivk na začetne vrednosti.
(o) Zaloga vrednosti: 
 (-) USPEH: ponastavljanje uspešno
 (-) NAPAKA: ponastavljanje ni bilo uspešno
(o) Vhodni parametri: uporablja globalne spremenljivke - parametre algoritma ob zagonu
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PonastaviVrednostiPodatkovnihStruktur()
{
  bpozicija = NEVELJAVNO;
  spozicija = NEVELJAVNO;
  trgovanje = ZAPRTO;
  return( USPEH );
} // PonastaviVrednostiPodatkovnihStruktur



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PostaviSL( int id, double r )
---------------------------------------
(o) Funkcionalnost: Funkcija poziciji z id-jem id postavi stop loss r točk od vstopne cene:
 (-) če gre za nakupno pozicijo, potem se odmik r PRIŠTEJE k ceni odprtja. Ko je enkrat stop loss postavljen nad ceno odprtja, ga ni več mogoče postaviti pod ceno odprtja, tudi če 
     podamo negativen r
 (-) če gre za prodajno pozicijo, potem se odmik r ODŠTEJE od cene odprtja. Ko je enkrat stop loss postavljen pod ceno odprtja, ga ni več mogoče postaviti nad ceno odprtja, tudi če 
     podamo negativen r
(o) Zaloga vrednosti:
 (-) USPEH: ponastavljanje uspešno
 (-) NAPAKA: ponastavljanje ni bilo uspešno
(o) Vhodni parametri:
 (-) id: oznaka pozicije
 (-) odmik: odmik
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PostaviSL( int id, double odmik )
{
  double ciljniSL;
  bool   modifyRezultat;
  int    selectRezultat;
  string sporocilo;

  selectRezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( selectRezultat == false ) 
  { 
    Print( "Trend-", verzija, ":[", stevilkaIteracije, "]:",  ":PostaviSL:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( NAPAKA ); 
  }
  
  if( OrderType() == OP_BUY ) { if( OrderStopLoss() >= OrderOpenPrice() ) { return( USPEH ); } else { ciljniSL = OrderOpenPrice() + odmik; } } 
  else                        { if( OrderStopLoss() <= OrderOpenPrice() ) { return( USPEH ); } else { ciljniSL = OrderOpenPrice() - odmik; } }
  
  modifyRezultat = OrderModify( id, OrderOpenPrice(), ciljniSL, 0, 0, clrNONE );
  if( modifyRezultat == false ) 
  { 
    Print( "Trend-", verzija, ":[", stevilkaIteracije, "]:", ":PostaviSL:OPOZORILO: Pozicije ", id, " ni bilo mogoče ponastaviti SL. Preveri ali je že ponastavljeno. Koda napake: ", GetLastError() ); 
    Print( "Trend-", verzija, ":[", stevilkaIteracije, "]:", ":PostaviSL:Obstoječi SL = ", DoubleToString( OrderStopLoss(), 5 ), " Ciljni SL = ", DoubleToString( ciljniSL, 5 ) );
    sporocilo = "Trend-" + verzija + ":PostaviSL:Postavi SL pozicije " + id + " na " + DoubleToString( ciljniSL, 5 );
    SendNotification( sporocilo );
    return( NAPAKA ); 
  }           
  else 
  { 
    return( USPEH ); 
  }
} // PostaviSL



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PozicijaZaprta( int id )
----------------------------------
(o) Funkcionalnost: Funkcija pove ali je pozicija s podanim id-jem zaprta ali ne. 
(o) Zaloga vrednosti:
 (-) true : pozicija je zaprta.
 (-) false: pozicija je odprta.
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool PozicijaZaprta( int id )
{
  int Rezultat;

  Rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat         == false ) { Print( "Trend-", verzija, ":[", stevilkaIteracije, "]:", ":PozicijaZaprta:OPOZORILO: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( true );}
  if( OrderCloseTime() == 0     ) { return( false ); } 
  else                            { return( true );  }
} // PozicijaZaprta



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PreberiIteracijo( int stIteracije )
(o) Funkcionalnost:
 (-) prebere naslednje parametre algoritma iz datoteke Trend-n.dat:
  (*) odmik od cene indikatorja, pri kateri odpremo novo pozicijo
  (*) velikost pozicij v lotih - L
  (*) profitni cilj - p
  (*) odmik za stop loss
  (*) indikator samodejnega ponovnega zagona - samodejniPonovni Zagon
 (-) pregleda odprte nakupne pozicije in če obstaja takšna, ki pripada iteraciji n, jo dodeli spremenljivki bpozicija
 (-) pregleda odprte prodajne pozicije in če obstaja takšna, ki pripada iteraciji n, jo dodeli spremenljivki spozicija
(o) Zaloga vrednosti: 
 (-) USPEH: če so bile vrednosti prebrane brez napak
 (-) NAPAKA: če je prišlo pri branju vrednosti do napake
(o) Vhodni parametri: številka iteracije, ostalo pridobimo iz globalnih spremenljivk
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PreberiIteracijo( int stIteracije )
{
  int    rocajDatoteke;
  string imeDatoteke;

  imeDatoteke = StringConcatenate( "Trend-", stIteracije, ".dat" );
  ResetLastError();
  rocajDatoteke = FileOpen( imeDatoteke, FILE_READ|FILE_BIN );
  if( rocajDatoteke != INVALID_HANDLE)
  {
    d                     = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    L                     = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    p                     = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    samodejniPonovniZagon = FileReadInteger( rocajDatoteke, INT_VALUE    );
    odmikSL               = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    Print( "Branje stanja iteracije iz datoteke ", imeDatoteke, ": -------------------------------------------------------------------------" );
    Print( "  Razdalja med osnovnima ravnema za nakup in prodajo [d]: ",         DoubleToString( d,       5 ) );
    Print( "  Velikost pozicij v lotih [L]: ",                                   DoubleToString( L,       5 ) );
    Print( "  Profitni cilj [p]: ",                                              DoubleToString( p,       5 ) );
    Print( "  Indikator samodejnega ponovnega zagona [samodejniPonovniZagon]: ", samodejniPonovniZagon        );
    Print( "  Odmik stop loss [odmikSL]: ",                                      DoubleToString( odmikSL, 5 ) );
    Print( "--------------------------------------------------------------------------------------------------------------------------------------------" );
    FileClose( rocajDatoteke );
  }
  else 
  { Print( "Trend-", verzija, ":PreberiIteracijo:USODNA NAPAKA: Odpiranje datoteke ", imeDatoteke, " ni bilo uspešno." ); return( NAPAKA ); }
  VpisiOdprtePozicije( stIteracije );
  return( USPEH );
} // PreberiIteracijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ShraniIteracijo( stIteracije )
---------------------------
(o) Funkcionalnost: Funkcija shrani podatke o trenutni iteraciji n v datoteko:
 (-) zapiše naslednje parametre algoritma v datoteke M5-n.dat:
  (*) odmik od cene indikatorja, pri kateri odpremo novo pozicijo
  (*) velikost pozicij v lotih - L
  (*) profitni cilj - p
  (*) odmik za stop loss
  (*) indikator samodejnega ponovnega zagona - samodejniPonovni Zagon
(o) Zaloga vrednosti:
 (-) USPEH  - odpiranje datoteke je bilo uspešno
 (-) NAPAKA - odpiranje datoteke ni bilo uspešno
(o) Vhodni parametri: eksplicitno sta podana spodnji dve vrednosti, ostale vrednosti se preberejo iz globalnih spremenljivk.
  (*) stIteracije - številka iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int ShraniIteracijo( int stIteracije )
{
  int    rocajDatoteke;
  string imeDatoteke;

  imeDatoteke = StringConcatenate( "Trend-", stIteracije, ".dat" );
  rocajDatoteke = FileOpen( imeDatoteke, FILE_WRITE|FILE_BIN );
  if( rocajDatoteke != INVALID_HANDLE)
  {
    FileWriteDouble ( rocajDatoteke, d    );
    FileWriteDouble ( rocajDatoteke, L    );
    FileWriteDouble ( rocajDatoteke, p    );
    FileWriteInteger( rocajDatoteke, samodejniPonovniZagon );
    FileWriteDouble ( rocajDatoteke, odmikSL );
    Print( "Zapisovanje stanja iteracije ", stIteracije, " v datoteko ", imeDatoteke, ": -------------------------------------------------------------------------" );
    Print( "  Razdalja med osnovnima ravnema za nakup in prodajo [d]: ",         DoubleToString( d,       5 ) );
    Print( "  Velikost pozicij v lotih [L]: ",                                   DoubleToString( L,       5 ) );
    Print( "  Profitni cilj [p]: ",                                              DoubleToString( p,       5 ) );
    Print( "  Indikator samodejnega ponovnega zagona [samodejniPonovniZagon]: ", samodejniPonovniZagon        );
    Print( "  Odmik stop loss [odmikSL]: ",                                      DoubleToString( odmikSL, 5 ) );
    Print( "--------------------------------------------------------------------------------------------------------------------------------------------" );
    FileClose( rocajDatoteke );
  }
  else 
  { Print( "Trend-", verzija, ":ShraniIteracijo:USODNA NAPAKA: Odpiranje datoteke ", imeDatoteke, " ni bilo uspešno." ); return( NAPAKA ); }
  return( USPEH );
} // ShraniIteracijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VpisiOdprtePozicije( int st )
----------------------------------
(o) Funkcionalnost: pregleda vse trenutno odprte pozicije in prepiše tiste, ki pripadajo iteraciji st na ustrezno raven v tabelah bpozicije / spozicije
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: st - številka iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int VpisiOdprtePozicije( int st )
{
  int    stUkazov;     // stevilo odprtih pozicij v terminalu

  stUkazov  = OrdersTotal();
  for( int i = 0; i < stUkazov; i++ )
  {
    if( OrderSelect( i, SELECT_BY_POS ) == false ) 
    { Print( "Trend", verzija, ":VpisiOdprtePozicije:OPOZORILO: Napaka pri dostopu do odprtih pozicij." ); } 
    else                   
    {
      if( st == OrderMagicNumber(); ) 
      { 
        switch( OrderType() ) 
        {
          case OP_BUY:  bpozicija = OrderTicket(); Print( "BUY pozicija ", OrderTicket(), ", iteracije ", st, " vpisana."   ); break;
          case OP_SELL: spozicija = OrderTicket(); Print( "SELL pozicija ", OrderTicket(), ", iteracije ", st, " vpisana. " ); break; 
          default: Print( "Trend-", verzija, ":VpisiOdprtePozicije:OPOZORILO: Nepričakovana vrsta ukaza." ); 
        }
      }
    } 
  } 
  return( USPEH );
} // VpisiOdprtePozicije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ZapriPozicijo( int id )
---------------------------------
(o) Funkcionalnost: Zapre pozicijo z oznako id po trenutni tržni ceni.
(o) Zaloga vrednosti:
 (-) true: če je bilo zapiranje pozicije uspešno;
 (-) false: če zapiranje pozicije ni bilo uspešno; 
(o) Vhodni parametri: id - oznaka pozicije.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ZapriPozicijo( int id )
{
  int Rezultat;

  Rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat == false ) 
    { Print( "Trend-", verzija, ":[", stevilkaIteracije, "]:", ":ZapriPozicijo::NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( false ); }
  switch( OrderType() )
  {
    case OP_BUY : return( OrderClose ( id, OrderLots(), Bid, 0, Green ) );
    case OP_SELL: return( OrderClose ( id, OrderLots(), Ask, 0, Red   ) );
    default:      return( OrderDelete( id ) );
  }  
} // ZapriPozicijo



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* SERVISNE FUNKCIJE                                                                                                                                                                    *
* Urejene po abecednem vrstnem redu                                                                                                                                                    *
*                                                                                                                                                                                      *
* Servisnih funkcij algoritem ne uporablja, služijo kot pripomočki, kadar gre pri izvajanju algoritma kaj narobe. Vstavi se jih v blok namenjen servisnim funkcijam znotraj init       *
****************************************************************************************************************************************************************************************
*/

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PrepisiZapisIteracije( int stIteracije, double dd, double rr, double cc, double LL, double pp, int spz, string imeKopije )
(o) Funkcionalnost: 
 (-) preimenuje datoteko, ki hrani podatke o iteraciji stIteracije v datoteko z imenom podanim v parametru imeKopije
 (-) ponovno zapiše datoteko s podatki o iteraciji s podatki podanimi v parametrih funkcije:
  (*) razdalja med osnovnima ravnema - dd
  (*) razdalja med dodatnimi ravnmi za prodajo ali nakup - rr
  (*) začetna cena - cc
  (*) velikost pozicij v lotih - LL
  (*) profitni cilj - pp
  (*) indikator samodejnega ponovnega zagona - spz
(o) Zaloga vrednosti:
 (-) USPEH  - prepis datoteke je bil uspešen
 (-) NAPAKA - prepis datoteke ni bil uspešen
(o) Vhodni parametri: 
  (*) stIteracije - številka iteracije, katere datoteko bomo prepisali.
  (*) dd, rr, cc, LL, pp, spz - so opisani že zgoraj
  (*) imeKopije cena - cena, ki jo shranimo kot začetno ceno iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool PrepisiZapisIteracije( int stIteracije, double dd, double rr, double cc, double LL, double pp, int spz, double slo, string imeKopije )
{
  int    rocajDatoteke;
  string imeDatoteke;

  imeDatoteke = StringConcatenate( "M5-", stIteracije, ".dat" );
  if( FileMove( imeDatoteke, 0, imeKopije, FILE_REWRITE ) == false ) 
  { 
    Print( "M5-V", verzija, ":PrepisiZapisIteracije:USODNA NAPAKA: Preimenovanje datoteke ", imeDatoteke, " ni bilo uspešno. Koda napake: ", GetLastError() ); return( NAPAKA );
  }
  
  rocajDatoteke = FileOpen( imeDatoteke, FILE_WRITE|FILE_BIN );
  if( rocajDatoteke != INVALID_HANDLE)
  {
    FileWriteDouble ( rocajDatoteke, dd  );
    FileWriteDouble ( rocajDatoteke, rr  );
    FileWriteDouble ( rocajDatoteke, cc  );
    FileWriteDouble ( rocajDatoteke, LL  );
    FileWriteDouble ( rocajDatoteke, pp  );
    FileWriteInteger( rocajDatoteke, spz );
    FileWriteDouble ( rocajDatoteke, slo );
    Print( "Zapisovanje stanja iteracije ", stIteracije, " v datoteko ", imeDatoteke, ": -------------------------------------------------------------------------" );
    Print( "  Razdalja med osnovnima ravnema za nakup in prodajo [d]: ",          DoubleToString( dd, 5 ) );
    Print( "  Razdalja med dodatnimi ravnmi za nakup in prodajo [r]: ",           DoubleToString( rr, 5 ) );
    Print( "  Začetna cena [cz]: ",                                               DoubleToString( cc, 5 ) );
    Print( "  Velikost pozicij v lotih [L]: ",                                    DoubleToString( LL, 5 ) );
    Print( "  Profitni cilj [p]: ",                                               DoubleToString( pp, 5 ) );
    Print( "  Indikator samodejnega ponovnega zagona [samodejniPonovniZagon]: ", spz );
    Print( "  Odmik stop loss [odmikSL]: ",                                      DoubleToString( slo, 5 ) );
    Print( "--------------------------------------------------------------------------------------------------------------------------------------------" );
    FileClose( rocajDatoteke );
  }
  else 
  { Print( "M5-V", verzija, ":ShraniIteracijo:USODNA NAPAKA: Odpiranje datoteke ", imeDatoteke, " ni bilo uspešno." ); return( NAPAKA ); }
  return( USPEH );
} // PrepisiZapisIteracije



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* FUNKCIJE DKA                                                                                                                                                                         *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S0CakanjeNaZagon() 
----------------------------
V to stanje vstopimo po zaključenem nastavljanju začetnih vrednosti. Čakamo na prehod čez črto indikatorja. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S0CakanjeNaZagon()
{
  double c = CenaIndikatorja();
  
  // najprej preverimo ali je morda trgovanje zaprto in so izpolnjeni pogoji za odpiranje
  if( ( trgovanje == ZAPRTO ) && ( zacetnaPozicija == NAD ) && ( Ask <= c ) ) { trgovanje = ODPRTO; }
  if( ( trgovanje == ZAPRTO ) && ( zacetnaPozicija == POD ) && ( Bid >= c ) ) { trgovanje = ODPRTO; }
  
  // preverimo ali je izpolnjen pogoj za odpiranje SELL pozicij
  if( ( trgovanje == ODPRTO ) && ( Ask <= ( c - d ) ) ) 
  { 
    spozicija1 = OdpriPozicijo( OP_SELL, 2*L, c, c - d - p ); 
    spozicija2 = OdpriPozicijo( OP_SELL,   L, c, 0         );
    return( S2 );
  }
  
  // preverimo ali je izpolnjen pogoj za odpiranje BUY pozicij
  if( ( trgovanje == ODPRTO ) && ( Bid >= ( c + d ) ) ) 
  { 
    bpozicija1 = OdpriPozicijo( OP_BUY, 2*L, c, c + d + p ); 
    bpozicija2 = OdpriPozicijo( OP_BUY,   L, c, 0         );
    return( S1 );
  }
  
  // če ni izpolnjen nobeden od pogojev, ostanemo v stanju S0
  return( S0 );
} // S0CakanjeNaZagon



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S1Nakup()
V tem stanju se znajdemo, ko je valutni par dosegel zahtevano razdaljo d od vrednosti indikatorja in sta odprti obe poziciji.
V tem stanju čakamo, da bo doseženo naslednje:
(-) take profit prve pozicije;
(-) izpolnjen pogoj za postavljanje SL druge pozicije na break even;
(-) izpolnjen pogoj za zapiranje druge pozicije in prehod v prodajo. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S1Nakup()
{ 
  double c; // vrednost indikatorja
  
  c = CenaIndikatorja();
  
  // preverimo ali je izpolnjen pogoj za postavljanje SL pozicij na BE
  if( IzpolnjenPogojzaBE( bpozicija1 ) == true ) { PostaviSL( bpozicija1, 0 ); }
  if( IzpolnjenPogojzaBE( bpozicija2 ) == true ) { PostaviSL( bpozicija2, 0 ); }
  
  // preverimo ali sta morda obe poziciji zaprti (to se zgodi če je dosežen SL) - v tem primeru gremo v S4 in od tam v S0 - odvisno od nastavitev
  if( ( PozicijaZaprta( bpozicija1 ) == true ) && ( PozicijaZaprta( bpozicija2 ) == true ) ) { return( S4 ); }
  
  // preverimo ali je izpolnjen pogoj za zapiranje nakupnih pozicij in odpiranje prodajnih pozicij.
  // Če da, potem zapremo bpozicija2 (bpozicija1 mora biti že zaprta) in gremo v S4 od tam pa v S0 - odvisno od nastavitev kjer je poskrbljeno za odpiranje novih pozicij
  if( Ask <= ( c - d ) ) 
  {
    if( PozicijaZaprta( bpozicija2 ) == false ) { ZapriPozicijo( bpozicija2 ); }
    return( S4 );
  }
  
  // če ni izpolnjenih nobenih drugih pogojev, potem ostanemo v stanju S1
  return( S1 );
} // S1Nakup



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S2Prodaja()
V tem stanju se znajdemo, ko je valutni par dosegel zahtevano razdaljo d od vrednosti indikatorja in sta odprti obe poziciji.
V tem stanju čakamo, da bo doseženo naslednje:
(-) take profit prve pozicije;
(-) izpolnjen pogoj za postavljanje SL druge pozicije na break even;
(-) izpolnjen pogoj za zapiranje druge pozicije in prehod v prodajo. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S2Prodaja()
{ 
  double c; // vrednost indikatorja
  
  c = CenaIndikatorja();
  
  // preverimo ali je izpolnjen pogoj za postavljanje SL pozicij na BE
  if( IzpolnjenPogojzaBE( spozicija1 ) == true ) { PostaviSL( spozicija1, 0 ); }
  if( IzpolnjenPogojzaBE( spozicija2 ) == true ) { PostaviSL( spozicija2, 0 ); }
  
  // preverimo ali sta morda obe poziciji zaprti (to se zgodi če je dosežen SL) - v tem primeru gremo v S4, od tam pa v S0 - odvisno od nastavitev
  if( ( PozicijaZaprta( spozicija1 ) == true ) && ( PozicijaZaprta( spozicija2 ) == true ) ) { return( S4 ); }
  
  // preverimo ali je izpolnjen pogoj za zapiranje nakupnih pozicij in odpiranje prodajnih pozicij.
  // Če da, potem zapremo spozicija2 (spozicija1 mora biti že zaprta) in se vrnemo v S4, od tam pa v S0 - odvisno od nastavitev, tam je poskrbljeno za odpiranje novih pozicij
  if( Bid >= ( c + d ) ) 
  {
    if( PozicijaZaprta( spozicija2 ) == false ) { ZapriPozicijo( spozicija2 ); }
    return( S4 );
  }
  
  // če ni izpolnjenih nobenih drugih pogojev, potem ostanemo v stanju S2
  return( S2 );
} // S2Prodaja



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S4Zakljucek()
V tem stanju se znajdemo, ko je bil dosežen profitni cilj. Če je vrednost parametra samodejni zagon enaka NE, potem v tem stanju ostanemo, dokler uporabnik ročno ne prekine delovanja 
algoritma. Če je vrednost parametra samodejni zagon enaka DA, potem ustrezno ponastavimo stanje algoritma in ga ponovno poženemo.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S4Zakljucek()
{ 
  if( samodejniPonovniZagon > 0 ) { return( S0 ); } else { return( S4 ); }
} // S4Zakljucek
