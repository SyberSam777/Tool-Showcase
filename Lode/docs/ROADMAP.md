# Roadmap

## 1. Field-collision namespacing (next)

Parsed JSON log bodies currently merge into the root of the document, so an application field named
`level`, `host`, or `message` collides with lode's own metadata, and two applications disagreeing on
the type of a field collide with each other. Today this is contained with an index template setting
`ignore_malformed: true` — the document indexes, the offending field is silently dropped.

Fix: promote all parsed application fields under `fields.*`, leaving the root namespace exclusively
for lode-generated metadata. Requires a new index template, a `lode-*`-to-`lode-v2-*` reindex path,
and a `schema_version` field so a mixed-version fleet is readable during rollout.

## 2. Cold-tier shipping

Second output sink writing to object storage (OCI Object Storage / S3) in Parquet, so the hot ES
tier can hold a short retention window while the compliance retention window lives cheaply.

## 3. Structured redaction

Redaction currently operates on the rendered line. Once (1) lands, rules can target specific parsed
fields (`fields.user.email`) rather than pattern-matching the whole record, which is both faster
and drastically lower false-positive.

## 4. Baton evidence refs

Emit content-addressed (`sha256:`) evidence handles on ship, so a Baton `Action` can cite an exact
immutable log record rather than a query that may return something different later.
