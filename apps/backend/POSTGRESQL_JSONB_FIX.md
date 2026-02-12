# PostgreSQL JSONB Type Handler Fix

## Problem
When migrating from MySQL to PostgreSQL, columns defined as `JSONB` in PostgreSQL were causing insertion errors:

```
ERROR: column "project_info" is of type jsonb but expression is of type character varying
```

This occurred because MyBatis Plus was trying to insert Java `String` values directly into PostgreSQL `JSONB` columns without proper type conversion.

## Solution
Created a custom MyBatis TypeHandler (`JsonbTypeHandler`) that properly converts between Java String (containing JSON) and PostgreSQL JSONB type.

### Files Created
- `apps/backend/ai-doc-system-model/src/main/java/com/aiid/aidoc/model/handler/JsonbTypeHandler.java`

### Files Modified
1. **Document.java** - Added `@TableField(typeHandler = JsonbTypeHandler.class)` to:
   - `projectInfo`
   - `metaTags`

2. **DocumentBlock.java** - Added `@TableField(typeHandler = JsonbTypeHandler.class)` to:
   - `docReference`
   - `chunkReference`
   - `metadata`

3. **DocumentTemplate.java** - Added `@TableField(typeHandler = JsonbTypeHandler.class)` to:
   - `chapters`

## How It Works
The `JsonbTypeHandler` wraps String values in a PostgreSQL `PGobject` with type "jsonb" before insertion, and extracts the String value when reading from the database.

## Testing
After applying this fix:
1. Rebuild the project: `mvn clean install`
2. Restart the application: `mvn spring-boot:run`
3. Test document creation via API

The error should no longer occur when inserting documents with JSON data.
