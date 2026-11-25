#!/usr/bin/env python3
"""Load query.csv into SQLite and enrich each film from Wikidata (SPARQL endpoint).

Usage: python3 ingest.py [--limit N] [--db movies.db] [--batch 150]
Resumable: films already enriched (fetched_at NOT NULL) are skipped.
"""
import argparse, csv, json, time, urllib.parse, urllib.request, urllib.error
from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from models import Base, Film, FilmAttr, get_engine

ENDPOINT = "https://query.wikidata.org/sparql"
UA = "CSE478-MovieAdaptations/0.1 (student project)"

LIST_VARS = {"directors": "director", "genres": "genre", "countries": "country",
             "langs": "language", "basedOn": "based_on_work"}


def query(qids):
    values = " ".join(f"wd:{q}" for q in qids)
    sparql = f"""
SELECT ?film (SAMPLE(?imdb) AS ?imdb_) (MAX(?dur) AS ?dur_) (MAX(?budget) AS ?budget_)
       (MAX(?box) AS ?box_) (SAMPLE(?sl) AS ?sl_)
       (GROUP_CONCAT(DISTINCT ?dirL;separator="|") AS ?directors)
       (GROUP_CONCAT(DISTINCT ?genL;separator="|") AS ?genres)
       (GROUP_CONCAT(DISTINCT ?ctyL;separator="|") AS ?countries)
       (GROUP_CONCAT(DISTINCT ?langL;separator="|") AS ?langs)
       (GROUP_CONCAT(DISTINCT ?srcL;separator="|") AS ?basedOn)
WHERE {{
  VALUES ?film {{ {values} }}
  OPTIONAL {{ ?film wdt:P345 ?imdb }}
  OPTIONAL {{ ?film wdt:P2047 ?dur }}
  OPTIONAL {{ ?film wdt:P2769 ?budget }}
  OPTIONAL {{ ?film wdt:P2142 ?box }}
  OPTIONAL {{ ?film wikibase:sitelinks ?sl }}
  OPTIONAL {{ ?film wdt:P57 ?d. ?d rdfs:label ?dirL FILTER(lang(?dirL)="en") }}
  OPTIONAL {{ ?film wdt:P136 ?g. ?g rdfs:label ?genL FILTER(lang(?genL)="en") }}
  OPTIONAL {{ ?film wdt:P495 ?c. ?c rdfs:label ?ctyL FILTER(lang(?ctyL)="en") }}
  OPTIONAL {{ ?film wdt:P364 ?l. ?l rdfs:label ?langL FILTER(lang(?langL)="en") }}
  OPTIONAL {{ ?film wdt:P144 ?s. ?s rdfs:label ?srcL FILTER(lang(?srcL)="en") }}
}} GROUP BY ?film"""
    data = urllib.parse.urlencode({"query": sparql}).encode()
    req = urllib.request.Request(ENDPOINT, data=data, headers={
        "User-Agent": UA, "Accept": "application/sparql-results+json"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.load(r)["results"]["bindings"]
        except urllib.error.HTTPError as e:
            wait = int(e.headers.get("Retry-After", 5 * 2 ** attempt)) if e.code in (429, 503) else 5 * 2 ** attempt
        except Exception:
            wait = 5 * 2 ** attempt
        time.sleep(wait)
    raise RuntimeError("Wikidata query failed repeatedly")


def num(b, k):
    try:
        return float(b[k]["value"]) if k in b else None
    except ValueError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="query.csv")
    ap.add_argument("--db", default="movies.db")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--batch", type=int, default=150)
    a = ap.parse_args()

    engine = get_engine(f"sqlite:///{a.db}")
    Base.metadata.create_all(engine)
    with open(a.csv, newline="", encoding="utf-8") as f:
        rows = [dict(qid=r["film"].rsplit("/", 1)[1], label=r["filmLabel"],
                     pub_year=int(r["pubYear"]) if r["pubYear"].isdigit() else None,
                     is_based_on=r["is_basedOn"] == "true", is_sequel=r["sequelOrMore"] == "true")
                for r in csv.DictReader(f)]

    with Session(engine) as db:
        for i in range(0, len(rows), 5000):  # INSERT OR IGNORE keeps reruns idempotent
            db.execute(sqlite_insert(Film).on_conflict_do_nothing(), rows[i:i + 5000])
        db.commit()

        todo = list(db.scalars(select(Film.qid).where(Film.fetched_at.is_(None)).order_by(Film.qid)))
        if a.limit:
            todo = todo[:a.limit]
        print(f"loaded {len(rows)} rows; {len(todo)} to enrich", flush=True)

        t0 = time.time()
        for i in range(0, len(todo), a.batch):
            chunk = todo[i:i + a.batch]
            attrs = []
            for b in query(chunk):
                qid = b["film"]["value"].rsplit("/", 1)[1]
                db.execute(update(Film).where(Film.qid == qid).values(
                    imdb_id=b.get("imdb_", {}).get("value"), duration_min=num(b, "dur_"),
                    budget=num(b, "budget_"), box_office=num(b, "box_"),
                    sitelinks=int(num(b, "sl_") or 0), fetched_at=datetime.now()))
                for var, kind in LIST_VARS.items():
                    for v in filter(None, b.get(var, {}).get("value", "").split("|")):
                        attrs.append(dict(qid=qid, kind=kind, value=v))
            if attrs:
                db.execute(sqlite_insert(FilmAttr).on_conflict_do_nothing(), attrs)
            # films absent from the results (no data at all) still count as fetched
            db.execute(update(Film).where(Film.qid.in_(chunk), Film.fetched_at.is_(None))
                       .values(fetched_at=datetime.now()))
            db.commit()
            print(f"{min(i + a.batch, len(todo))}/{len(todo)}  {time.time()-t0:.0f}s", flush=True)
            time.sleep(1)


if __name__ == "__main__":
    main()
