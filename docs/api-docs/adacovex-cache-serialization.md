# Adacovex.Cache.Serialization

Encode X into a blob string suitable for Store.
@param X  Value to encode.
@return Blob string.

> **Note:** All items in this package are public.

## Functions

### function Deserialize (S : Standard.String; X : Adacovex.Cache.Serialization.T) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `S` | Blob string. |
| `X` | Decoded value. |

**Returns:** True on success.  False on malformed input.

### function Serialize (X : Adacovex.Cache.Serialization.T) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `X` | Value to encode. |

**Returns:** Blob string.
