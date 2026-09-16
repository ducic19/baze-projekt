DROP TABLE IF EXISTS Stavka_racuna CASCADE;
DROP TABLE IF EXISTS Racun CASCADE;
DROP TABLE IF EXISTS Artikl CASCADE;
DROP TABLE IF EXISTS Poklon_bon CASCADE;
DROP TABLE IF EXISTS Zaposlenik CASCADE;
DROP TABLE IF EXISTS Kupac CASCADE;
DROP TABLE IF EXISTS Vrsta_proizvoda CASCADE;
DROP TABLE IF EXISTS Album CASCADE;
DROP TABLE IF EXISTS Izdavacka_kuca CASCADE;
DROP TABLE IF EXISTS Izvodac CASCADE;

CREATE TABLE Izvodac (
    izvodac_id SERIAL PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    zemlja_podrijetla VARCHAR(50) NOT NULL
);

CREATE TABLE Izdavacka_kuca (
    izdavac_id SERIAL PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    sjediste VARCHAR(100) NOT NULL
);

CREATE TABLE Vrsta_proizvoda (
    vrsta_id SERIAL PRIMARY KEY,
    naziv VARCHAR(50) NOT NULL,
    opis TEXT
);

CREATE TABLE Album (
    album_id SERIAL PRIMARY KEY,
    naziv VARCHAR(150) NOT NULL,
    godina_izdanja INT NOT NULL,
    izvodac_id INT NOT NULL,
    izdavac_id INT NOT NULL,
    CONSTRAINT fk_album_izvodac FOREIGN KEY (izvodac_id) REFERENCES Izvodac(izvodac_id) ON DELETE CASCADE,
    CONSTRAINT fk_album_izdavac FOREIGN KEY (izdavac_id) REFERENCES Izdavacka_kuca(izdavac_id) ON DELETE CASCADE
);

CREATE TABLE Artikl (
    artikl_id SERIAL PRIMARY KEY,
    cijena DECIMAL(10, 2) NOT NULL,
    kolicina_na_zalihi INT NOT NULL DEFAULT 0,
    album_id INT NOT NULL,
    vrsta_id INT NOT NULL,
    CONSTRAINT fk_artikl_album FOREIGN KEY (album_id) REFERENCES Album(album_id) ON DELETE CASCADE,
    CONSTRAINT fk_artikl_vrsta FOREIGN KEY (vrsta_id) REFERENCES Vrsta_proizvoda(vrsta_id) ON DELETE CASCADE,
    CONSTRAINT artikl_cijena_ck CHECK (cijena > 0)
);

CREATE TABLE Kupac (
    kupac_id SERIAL PRIMARY KEY,
    ime VARCHAR(50) NOT NULL,
    prezime VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    broj_telefona VARCHAR(20)
);

CREATE TABLE Zaposlenik (
    zaposlenik_id SERIAL PRIMARY KEY,
    ime VARCHAR(50) NOT NULL,
    prezime VARCHAR(50) NOT NULL,
    pozicija VARCHAR(50) NOT NULL
);

CREATE TABLE Poklon_bon (
    poklon_id SERIAL PRIMARY KEY,
    vrijednost DECIMAL(10, 2) NOT NULL,
    datum_isteka DATE NOT NULL
);

CREATE TABLE Racun (
    racun_id SERIAL PRIMARY KEY,
    datum_vrijeme TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ukupan_iznos DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    kupac_id INT NOT NULL,
    zaposlenik_id INT NOT NULL,
    poklon_id INT UNIQUE, 
    CONSTRAINT fk_racun_kupac FOREIGN KEY (kupac_id) REFERENCES Kupac(kupac_id),
    CONSTRAINT fk_racun_zaposlenik FOREIGN KEY (zaposlenik_id) REFERENCES Zaposlenik(zaposlenik_id),
    CONSTRAINT fk_racun_bon FOREIGN KEY (poklon_id) REFERENCES Poklon_bon(poklon_id),
    CONSTRAINT racun_kupac_vrijeme_uq UNIQUE (kupac_id, datum_vrijeme)
);

CREATE TABLE Stavka_racuna (
    racun_id INT NOT NULL,
    artikl_id INT NOT NULL,
    kolicina INT NOT NULL,
    PRIMARY KEY (racun_id, artikl_id),
    CONSTRAINT fk_stavka_racun FOREIGN KEY (racun_id) REFERENCES Racun(racun_id) ON DELETE CASCADE,
    CONSTRAINT fk_stavka_artikl FOREIGN KEY (artikl_id) REFERENCES Artikl(artikl_id),
    CONSTRAINT stavka_kolicina_ck CHECK (kolicina >= 1)
);

CREATE INDEX idx_stavka_racuna_racun_id ON Stavka_racuna (racun_id);
CREATE INDEX idx_album_naziv ON Album (naziv);

-- Automatsko smanjivanje zalihe artikla nakon kupovine
CREATE OR REPLACE FUNCTION f_smanji_zalihu()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE Artikl 
    SET kolicina_na_zalihi = kolicina_na_zalihi - NEW.kolicina
    WHERE artikl_id = NEW.artikl_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_smanji_zalihu ON Stavka_racuna;
CREATE TRIGGER trg_smanji_zalihu
AFTER INSERT ON Stavka_racuna
FOR EACH ROW EXECUTE FUNCTION f_smanji_zalihu();


-- Zabrana prodaje ako nema dovoljno artikala na zalihi
CREATE OR REPLACE FUNCTION f_provjeri_zalihu()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_trenutno_na_zalihi INTEGER;
BEGIN
    SELECT kolicina_na_zalihi INTO v_trenutno_na_zalihi FROM Artikl WHERE artikl_id = NEW.artikl_id;
    IF v_trenutno_na_zalihi < NEW.kolicina THEN
        RAISE EXCEPTION 'Nedovoljna kolicina artikla na skladistu.';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_provjeri_zalihu ON Stavka_racuna;
CREATE TRIGGER trg_provjeri_zalihu
BEFORE INSERT ON Stavka_racuna
FOR EACH ROW EXECUTE FUNCTION f_provjeri_zalihu();


-- Dodavanje novog artikla s početnom zalihom 0
CREATE OR REPLACE PROCEDURE dodaj_novi_artikl(
    p_cijena NUMERIC, 
    p_album_id INTEGER,
    p_vrsta_id INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO Artikl (cijena, album_id, vrsta_id, kolicina_na_zalihi)
    VALUES (p_cijena, p_album_id, p_vrsta_id, 0);
END;
$$;

-- Zaprimanje robe i povećanje zalihe artikla
CREATE OR REPLACE PROCEDURE zaprimi_robu(
    p_artikl_id INTEGER, 
    p_kolicina INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE Artikl 
    SET kolicina_na_zalihi = kolicina_na_zalihi + p_kolicina
    WHERE artikl_id = p_artikl_id;
END;
$$;



INSERT INTO Izvodac (naziv, zemlja_podrijetla) VALUES 
('Pink Floyd', 'UK'), ('Daft Punk', 'Francuska'), ('Arctic Monkeys', 'UK'), 
('Dire Straits', 'UK'), ('Bruce Springsteen', 'SAD'), ('Silente', 'Hrvatska'), 
('Nirvana', 'SAD'), ('ABBA', 'Svedska');

INSERT INTO Izdavacka_kuca (naziv, sjediste) VALUES 
('Harvest Records', 'London'), ('Columbia Records', 'New York'), ('Croatia Records', 'Zagreb'), 
('Domino Recording Co', 'London'), ('Vertigo Records', 'London'), ('Geffen Records', 'Los Angeles'), 
('Polar Music', 'Stockholm');          

INSERT INTO Vrsta_proizvoda (naziv, opis) VALUES 
('Vinil (LP)', 'Gramofonska ploca od 12 inca'), ('CD', 'Kompaktni disk standardnog formata'), ('Kazeta', 'Audio kazeta');

INSERT INTO Album (naziv, godina_izdanja, izvodac_id, izdavac_id) VALUES 
('The Dark Side of the Moon', 1973, 1, 1), ('The Wall', 1979, 1, 2), ('Wish you were here', 1975, 1, 2),
('Pulse(Live)', 1995, 1, 2), ('The Division Bell', 1994, 1, 2), ('Meddle', 1971, 1, 1), ('Animals', 1977, 1, 1),
('Random Access Memories', 2013, 2, 2), ('Discovery', 2001, 2, 2), ('Homework', 1997, 2, 2), 
('The Car', 2022, 3, 4), ('Humbug', 2009, 3, 4), ('Favourite Worst Nightmare', 2007, 3, 4),
('Whatever People Say I Am, Thats What Im Not', 2006, 3, 4), 
('Dire Straits', 1978, 4, 5), ('Communique', 1979, 4, 5), ('Making Movies', 1980, 4, 5), 
('Born In The U.S.A.', 1984, 5, 2), ('Nebraska', 1982, 5, 2), ('Working On A Dream', 2009, 5, 2), 
('IV', 2022, 6, 3), ('Malo Magle, Malo Mjesecine', 2018, 6, 3), ('Nece Rijeka Zrakom Teci', 2015, 6, 3), 
('Lovac na cudesa', 2013, 6, 3), 
('In Utero', 1993, 7, 6), ('Nevermind', 1991, 7, 6), ('MTV Unplugged in New York', 1994, 7, 6), 
('Super Trouper', 1980, 8, 7), ('Voulez-Vous', 1979, 8, 7), ('Arrival', 1976, 8, 7); 

INSERT INTO Artikl (cijena, kolicina_na_zalihi, album_id, vrsta_id) VALUES 
(39.99, 5, 1, 1), (45.00, 3, 2, 1), (42.50, 4, 3, 1), (35.00, 8, 8, 1), (38.00, 6, 9, 1), 
(29.99, 12, 11, 1), (34.50, 7, 15, 1), (32.00, 10, 18, 1), (28.00, 5, 25, 1), (33.00, 4, 28, 1), 
(15.99, 20, 4, 2), (14.50, 15, 5, 2), (16.00, 10, 10, 2), (13.99, 18, 12, 2), (14.00, 25, 13, 2), 
(12.50, 14, 16, 2), (12.50, 15, 17, 2), (15.00, 11, 19, 2), (14.00, 9, 20, 2), (13.00, 30, 21, 2), 
(12.00, 22, 22, 2), (12.00, 25, 23, 2), (13.50, 15, 24, 2), (15.00, 19, 26, 2), (16.50, 12, 27, 2), 
(12.99, 40, 29, 2), (12.99, 35, 30, 2), (9.99, 2, 6, 3), (10.50, 3, 7, 3), (9.99, 5, 14, 3);    

INSERT INTO Kupac (ime, prezime, email, broj_telefona) VALUES 
('Ivan', 'Horvat', 'ivan.horvat@email.com', '091234567'), 
('Filip', 'Marić', 'filip.m@email.com', '092111222'),        
('Elena', 'Rodić', 'elena.r@email.com', '098333444'), ('Karlo', 'Babić', 'karlo.b@email.com', NULL),              
('Ana', 'Kovač', NULL, '091555666'), ('David', 'Bilić', 'david.b@email.com', NULL),              
('Mia', 'Pavlić', 'mia.p@email.com', '097777666'), ('Bruno', 'Smit', NULL, '099123987'),                        
('Lucija', 'Matić', 'lucija.m@email.com', NULL), ('Tomislav', 'Horvatić', 'tomislav.h@email.com', '091999888'),
('Lana', 'Kraljević', 'lana.k@email.com', NULL), ('Mateo', 'Jurić', 'mateo.j@email.com', '095444555'),        
('Sara', 'Marić', 'sara.m@email.com', NULL), ('Luka', 'Novak', 'luka.n@email.com', '092666777');          

INSERT INTO Zaposlenik (ime, prezime, pozicija) VALUES 
('Luka', 'Kovačić', 'Prodavač'), ('Ana', 'Jurić', 'Voditelj smjene'),     
('Stjepan', 'Petrić', 'Student prodavač'), ('Martina', 'Novak', 'Prodavač');          

INSERT INTO Poklon_bon (vrijednost, datum_isteka) VALUES (10.00, '2026-12-31'), (20.00, '2026-08-15'), (15.00, '2026-05-01'); 

INSERT INTO Racun (datum_vrijeme, ukupan_iznos, kupac_id, zaposlenik_id, poklon_id) VALUES 
('2026-06-25 10:00:00', 55.98, 1, 1, NULL), ('2026-06-25 11:00:00', 45.00, 2, 3, NULL),  
('2026-06-25 12:30:00', 39.99, 3, 1, NULL), ('2026-06-25 14:00:00', 76.00, 8, 3, NULL),  
('2026-06-25 15:45:00', 12.00, 9, 4, NULL), ('2026-06-25 16:20:00', 119.97, 10, 1, NULL),
('2026-06-25 17:10:00', 14.00, 3, 2, NULL), ('2026-06-25 18:00:00', 24.00, 14, 4, 1);   

INSERT INTO Stavka_racuna (racun_id, artikl_id, kolicina) VALUES 
(1, 1, 1), (1, 11, 1), (2, 2, 1), (3, 1, 1), (4, 5, 2), (5, 21, 1), (6, 1, 3), (7, 19, 1), (8, 22, 2);



COMMENT ON TABLE Kupac IS 'Evidencija registriranih kupaca te njihovi podatci za kontakt (u svrhu marketinga)';
COMMENT ON TABLE Zaposlenik IS 'Popis svih djelatnika u trgovini, uključujući studente i voditelje smjena.';
COMMENT ON TABLE Izvodac IS 'Podaci o glazbenim izvođačima, bendovima i njihovim zemljama podrijetla.';
COMMENT ON TABLE Album IS 'Katalog glazbenih albuma s pripadajućim vrstama proizvoda i godinama izdanja.';
COMMENT ON TABLE Izdavacka_kuca IS 'Evidencija diskografskih kuća koje izdaju albume i njihova sjedišta.';
COMMENT ON TABLE Vrsta_proizvoda IS 'Popis fizičkih oblika glazbenih izdanja(albuma) i njihovi opisi';
COMMENT ON COLUMN Vrsta_proizvoda.naziv IS 'Album može biti u jednom ili više od sljedećih formata: CD,Vinyl,kazeta';
COMMENT ON TABLE Artikl IS 'Evidencija konkretnih proizvoda, njihovih cijena i stanja na zalihi.';
COMMENT ON TABLE Poklon_bon IS 'Popis izdanih poklon bonova s pripadajućim vrijednostima i rokovima trajanja.';
COMMENT ON TABLE Racun IS 'Zaglavlja izdanih računa s podacima o kupcu, blagajniku i ukupnom iznosu.';
COMMENT ON TABLE Stavka_racuna IS 'Povezna tablica između računa i artikala s pripadajućim količinama prodaje.';


-- UPITI: 
-- novi artikl (Album 3, Format 1) s cijenom 50.00. Početna zaliha = 0
CALL dodaj_novi_artikl(50.00, 3, 1);

-- zaprimamo 15 komada novostvorenog artikla (ID = 31)
CALL zaprimi_robu(31, 15);

-- kupujemo 2 komada artikla 31 (ima ih 15, dopušteno)
INSERT INTO Stavka_racuna (racun_id, artikl_id, kolicina) VALUES (8, 31, 2);

-- zaliha artikla 31 se automatski smanjila s 15 na 13 komada
SELECT kolicina_na_zalihi FROM Artikl WHERE artikl_id = 31;

-- 5 jednostavnih upita:
--popis svih kupaca s mailom - kako bi im mogli poslati nove pondue, reklame i sl.
SELECT ime,prezime,email
FROM Kupac
WHERE email IS NOT NULL;

--zelimo popis studenata koji rade koji bi im mogli poslati obavijesti za smjene te produzetak ugovora
SELECT ime,prezime,pozicija
FROM Zaposlenik
WHERE pozicija='Student prodavač';

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
SELECT al.naziv AS album, sr.kolicina, r.racun_id
FROM Artikl ar
JOIN Album al ON ar.album_id = al.album_id
FULL JOIN Stavka_racuna sr ON ar.artikl_id = sr.artikl_id
FULL JOIN Racun r ON sr.racun_id = r.racun_id
WHERE sr.artikl_id IS NOT NULL AND r.racun_id IS NOT NULL;

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



COMMIT;
