"""Retail uiMapIDs -> the uiMapIDs of WoW Forever (it uses the numbers of Classic Era: 1429 is Elwynn Forest, retail 37 is)."""

R = {
    1: 1411, 7: 1412, 10: 1413, 2: 1416, 14: 1417, 15: 1418, 17: 1419, 18: 1420, 21: 1421, 22: 1422, 23: 1423, 25: 1424, 26: 1425, 27: 1426,
    32: 1427, 36: 1428, 37: 1429, 42: 1430, 47: 1431, 48: 1432, 49: 1433, 50: 1434, 210: 1434, 51: 1435, 52: 1436, 56: 1437, 57: 1438,
    62: 1439, 63: 1440, 64: 1441, 65: 1442, 66: 1443, 69: 1444, 70: 1445, 71: 1446, 76: 1447, 77: 1448, 78: 1449, 80: 1450, 81: 1451,
    83: 1452, 84: 1453, 85: 1454, 87: 1455, 88: 1456, 89: 1457, 90: 1458, 12: 1414, 13: 1415,
    # starting areas that retail has as maps of their own
    427: 1426, 461: 1411, 462: 1412, 463: 1411, 465: 1411, 469: 1429,
}


def m(x):
    """One map id."""
    try:
        return R.get(int(x), int(x))
    except Exception:
        return x


def remap(v):
    """A record: the 'm' field (a map id, or a table keyed by map ids) is turned to the Forever numbers; lists and sub tables too."""
    if isinstance(v, dict):
        out = {}
        for k, x in v.items():
            if k == "m" and isinstance(x, int):
                out[k] = m(x)
            elif k == "m" and isinstance(x, dict):
                out[k] = {m(a): remap(b) for a, b in x.items()}
            else:
                out[k] = remap(x)
        return out
    return v
