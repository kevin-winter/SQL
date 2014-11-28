alter view vw_importtocherwell as 
SELECT     a.id, a.Kaufdatum, a.InventarNummer, a.GarantieEnde, a.InReperatur, a.IstVerkauft, a.IstVerschrottet, a.IMEI, a.handytyp, a.Ort, b.Mobile, b.SimKarteInVerwendung, b.InVerwendung, b.StartDatum, b.EndDatum, b.LoginName, b.Nachname, b.Vorname, b.festnetzdurchwahl, b.HandyDurchwahl, b.Abkuerzung, b.SimKarte, b.Nummer,b.kundennummer
FROM
	(SELECT h.MobileID AS id, h.Kaufdatum, h.InventarNummer, h.GarantieEnde, h.InReperatur, h.IstVerkauft, h.IstVerschrottet, h.IMEI, REPLACE(t.HandyTyp, 'LH ', '') AS handytyp, l.Ort
	FROM dbo.tb_TEL_Handies AS h 
	JOIN dbo.tb_TEL_HandyTypen AS t ON h.TypeID = t.TypeID 
	JOIN dbo.tb_TEL_LagerOrt AS l ON h.LagerOrtID = l.ID
	WHERE (h.IstVerschrottet = 0) 
	AND (h.IstGeloescht = 0)) AS a 
LEFT OUTER JOIN
	(SELECT v.Mobile, v.SimKarteInVerwendung, v.InVerwendung, v.StartDatum, v.EndDatum, b.LoginName, b.Nachname, b.Vorname, 
	CASE WHEN festnetzdurchwahl LIKE '1%' THEN festnetzdurchwahl ELSE NULL END AS festnetzdurchwahl, 
	b.HandyDurchwahl, k.Abkuerzung, s.SimKarte,i.nummer as kundennummer, s.Nummer
	FROM dbo.tb_TEL_Verwendung AS v 
	LEFT OUTER JOIN dbo.tb_TEL_VerwendungsInfo AS vi 
	ON v.VerwendungsID = vi.VerwendungsID 
	LEFT OUTER JOIN dbo.tb_TEL_Besitzer AS b 
	ON b.BesitzerID = vi.BesitzerID 
	LEFT OUTER JOIN dbo.tb_TEL_ImportMapping i
	ON i.BesitzerID = b.BesitzerID
	LEFT OUTER JOIN dbo.tb_TEL_Kostenstelle AS k 
	ON b.KostenstellenID = k.KostenstellenID 
	LEFT OUTER JOIN dbo.tb_TEL_SimInfo AS s 
	ON s.SimInfoID = vi.SimInfoID
	where v.inverwendung = 1) AS b 
ON a.id = b.Mobile                                        
WHERE (b.EndDatum = 0)
OR (b.EndDatum IS NULL)


--ext Numbers
select nummer,'Mobile' as "Type", case when nachname like '%[_]D' then 'Data' else 'Mobile' end as "Usage", loginname, REPLACE(nachname,'_D',''), vorname, abkuerzung 
from lbhsv027.telefonie_neu.dbo.vw_importToCherwell
join Customer c
on  c.FirstName collate Latin1_General_CI_AS = i.vorname and
 c.LastName collate Latin1_General_CI_AS = replace(i.nachname, '(%', '')
and c.PrimaryOrganisationUnit collate Latin1_General_CI_AS = i.abkuerzung

--handydurchwahl
select '+43 50809 '+handydurchwahl,handydurchwahl,'Mobile' as "Type", case when nachname like '%[_]D' then 'Data' else 'Mobile' end as "Usage", loginname, nachname, vorname, abkuerzung 
from lbhsv027.telefonie_neu.dbo.vw_importtocherwell
where isnull(handydurchwahl,'') != ''

--simkarte
select distinct simkarte,i.nummer,kundennummer,recid, c.samaccountname, 
case when Mobile is not null and recid is null then abkuerzung 
when mobile is null then '6NA' end as OU
from lbhsv027.telefonie_neu.dbo.vw_importtocherwell i 
left join vw_MotelCherwellCustomer c
on i.besitzerid = c.besitzerid
order by ou,kundennummer

--handies
select distinct kaufdatum,inventarnummer,garantieende,imei,handytyp,ort,simkarte, recid, c.samaccountname, 
case when Mobile is not null and recid is null then abkuerzung 
when mobile is null then '6NA' end as OU
from lbhsv027.telefonie_neu.dbo.vw_importtocherwell i 
left join vw_MotelCherwellCustomer c
on i.besitzerid = c.besitzerid
order by ou
