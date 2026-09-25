import sqlite3
con = sqlite3.connect(r'D:\commonwealth-ga-server-master\out\server.db')
count = con.execute("SELECT COUNT(*) FROM map_game_info").fetchone()
print('row count:', count[0])
rows = con.execute("SELECT * FROM map_game_info LIMIT 5").fetchall()
for r in rows:
    print(r)
cols = con.execute("PRAGMA table_info(map_game_info)").fetchall()
for c in cols:
    print(c)
