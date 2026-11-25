#!/usr/bin/env python3
"""Export movies.db to interchange formats in ./export:
  films.json   - array of film objects, multi-valued fields as arrays (for D3 / JS / pandas)
  films.csv    - flat, multi-valued fields joined with '|' (for spreadsheets / R)
"""
import csv, json, os
from collections import defaultdict

from sqlalchemy import select
from sqlalchemy.orm import Session

from models import Film, FilmAttr, get_engine

KINDS = {"director": "directors", "genre": "genres", "country": "countries",
         "language": "languages", "based_on_work": "based_on_works"}
SCALARS = ["qid", "label", "pub_year", "is_based_on", "is_sequel", "imdb_id",
           "duration_min", "budget", "box_office", "sitelinks"]


def main(out="export"):
    os.makedirs(out, exist_ok=True)
    with Session(get_engine()) as db:
        attrs = defaultdict(lambda: defaultdict(list))
        for a in db.execute(select(FilmAttr).order_by(FilmAttr.qid, FilmAttr.kind, FilmAttr.value)).scalars():
            attrs[a.qid][a.kind].append(a.value)

        films = []
        for f in db.scalars(select(Film).order_by(Film.qid)):
            d = {k: getattr(f, k) for k in SCALARS}
            d["wikidata_url"] = f"https://www.wikidata.org/entity/{f.qid}"
            for k, name in KINDS.items():
                d[name] = attrs[f.qid].get(k, [])
            films.append(d)

    with open(f"{out}/films.json", "w", encoding="utf-8") as fh:
        json.dump(films, fh, ensure_ascii=False, separators=(",", ":"))

    list_cols = [c for c in films[0] if isinstance(films[0][c], list)]
    with open(f"{out}/films.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(films[0]))
        w.writeheader()
        for d in films:
            w.writerow({k: ("|".join(v) if k in list_cols else ("" if v is None else v)) for k, v in d.items()})
    print(f"exported {len(films)} films to {out}/")


if __name__ == "__main__":
    main()
