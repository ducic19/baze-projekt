-- 5 jednostavnih upita:
--popis svih kupaca s mailom - kako bi im mogli poslati nove pondue, reklame i sl.
SELECT ime,prezime,email
FROM Kupac
WHERE email IS NOT NULL;

--zelimo popis studenata koji rade koji bi im mogli poslati obavijesti za smjene te produzetak ugovora
SELECT ime,prezime,pozicija
FROM Zaposlenik
WHERE pozicija='Student prodavac';

--zanima nas koliko izvodaca, cije albume prodajemo, pricaju engleski jezik
SELECT naziv,zemlja_podrijetla
FROM Izvodac
WHERE zemlja_podrijetla='UK' OR zemlja_podrijetla='SAD';

--kupac kupuje poklon, budzet mu je 20e, sljedece artikle moze priustiti: 
SELECT artikl_id,cijena,kolicina_na_zalihi
FROM Artikl
WHERE cijena <= 20.00
ORDER BY cijena ASC;

--popis izdavackih kuca iz LA-a
SELECT naziv,sjediste
FROM Izdavacka_kuca
WHERE sjediste='Los Angeles'; 

-- 5 upita nad više tablica: 
-- implicitni join
--nazivi albuma i izvodaca, ali samo za one izvodace iz UK 
SELECT a.naziv as album_naziv, i.naziv as izvodac_naziv, i.zemlja_podrijetla
FROM Album a,Izvodac i
WHERE a.izvodac_id=i.izvodac_id AND i.zemlja_podrijetla='UK'
ORDER BY a.naziv;

--eksplicitni join 
--prikaz svih artikala u trgovini, cijena i format (od najskupljih)
SELECT al.naziv AS naziv_albuma, a.cijena, vp.naziv AS format_proizvoda
FROM Artikl a
INNER JOIN Album al ON a.album_id=al.album_id
INNER JOIN Vrsta_proizvoda vp ON a.vrsta_id = vp.vrsta_id
ORDER BY a.cijena DESC;

--left join 
-- popis svih kupaca i datumi/vrijeme nastanka racuna (ako kupac postoji ali nije kupio nista bit ce NULL)
SELECT k.ime,k.prezime,r.racun_id,r.datum_vrijeme
FROM Kupac k
LEFT JOIN Racun r ON k.kupac_id=r.kupac_id
ORDER BY k.prezime; 

-- right join 
-- popis aktivnih poklon bonova (racun_id je null i nije jos istekao datumski)
SELECT pb.poklon_id, pb.vrijednost, pb.datum_isteka
FROM Racun r
RIGHT JOIN Poklon_bon pb ON r.poklon_id = pb.poklon_id
WHERE r.racun_id IS NULL AND pb.datum_isteka>= CURRENT_DATE; 

-- full join 
-- popis stavki racuna i artikli, prikaz albuma i kolicine na racunima
SELECT al.naziv AS album, sr.kolicina, r.racun_id
FROM Artikl ar
JOIN Album al ON ar.album_id = al.album_id
FULL JOIN Stavka_racuna sr ON ar.artikl_id = sr.artikl_id
FULL JOIN Racun r ON sr.racun_id = r.racun_id;

-- 5 upita s agregirajućim funkcijama
-- broj izdanih računa po zaposleniku 
SELECT z.ime, z.prezime, COUNT(r.racun_id) AS broj_racuna
FROM Zaposlenik z
LEFT JOIN Racun r ON z.zaposlenik_id = r.zaposlenik_id
GROUP BY z.zaposlenik_id, z.ime, z.prezime
ORDER BY broj_racuna DESC;

-- ukupna količina artikala na zalihi prema formatu 
SELECT vp.naziv AS format_proizvoda, SUM(a.kolicina_na_zalihi) AS ukupno_na_zalihi
FROM Artikl a
JOIN Vrsta_proizvoda vp ON a.vrsta_id = vp.vrsta_id
GROUP BY vp.vrsta_id, vp.naziv
ORDER BY ukupno_na_zalihi DESC;

-- prosječna cijena artikala po svakom formatu
SELECT vp.naziv AS format_proizvoda, ROUND(AVG(a.cijena), 2) AS prosjecna_cijena
FROM Artikl a
JOIN Vrsta_proizvoda vp ON a.vrsta_id = vp.vrsta_id
GROUP BY vp.vrsta_id, vp.naziv 
ORDER BY prosjecna_cijena DESC;

-- zarada tj. potrosnja po kupcu (vise od 30€)
SELECT k.ime, k.prezime, SUM(r.ukupan_iznos) AS ukupno_potrosio
FROM Kupac k
JOIN Racun r ON k.kupac_id = r.kupac_id
GROUP BY k.kupac_id, k.ime, k.prezime
HAVING SUM(r.ukupan_iznos) > 30.00
ORDER BY ukupno_potrosio DESC;

-- najskuplji i najjeftiniji artikl u trgovini
SELECT MIN(cijena) AS najniza_cijena, MAX(cijena) AS najvisa_cijena
FROM Artikl;

-- podupiti, ugniježđeni upiti, skupovne operacije 
-- artikli skuplji od prosjeka
SELECT al.naziv as album, a.cijena
FROM Artikl a
JOIN Album al on a.album_id=al.album_id
WHERE a.cijena > (SELECT AVG(cijena) FROM Artikl)
ORDER BY a.cijena DESC; 

-- popis kupaca koji su kupili barem jedan artikl
SELECT ime, prezime
FROM Kupac 
WHERE kupac_id IN (SELECT DISTINCT kupac_id FROM Racun)
ORDER BY prezime; 

-- popis albuma izvođača koji dijele zemlju podrijetla s Pink Floydom 
SELECT naziv AS naziv_albuma, godina_izdanja
FROM Album
WHERE izvodac_id IN (
	SELECT izvodac_id
	FROM Izvodac
	WHERE zemlja_podrijetla= (
		SELECT zemlja_podrijetla
		FROM Izvodac
		WHERE naziv = 'Pink Floyd'  -- ako ne želimo uključiti Pink FLoyd
	) --dodajemo sljedeci uvjet: 
	--AND naziv != 'Pink Floyd'
);

-- spoj imena i prezimena svih kupaca i zaposlenika/svi ljudi u sustavu
SELECT ime, prezime, 'Kupac' AS uloga FROM Kupac
UNION
SELECT ime,prezime, 'Zaposlenik' AS uloga FROM Zaposlenik
ORDER BY prezime,ime; 

-- popis registriranih kupaca koji nisu još ništa kupili 
SELECT kupac_id, ime, prezime FROM Kupac
EXCEPT
SELECT k.kupac_id, k.ime, k.prezime FROM Kupac k JOIN Racun r ON k.kupac_id = r.kupac_id
ORDER BY prezime;

