import sqlite3
con = sqlite3.connect(r'D:\commonwealth-ga-server-master\out\server.db')
rows = con.execute("SELECT * FROM map_game_info ORDER BY map_name").fetchall()
for r in rows:
    print(r)
print('---')
print('Dome3 present:', con.execute("SELECT * FROM map_game_info WHERE map_name LIKE '%Dome3%'").fetchall())
print('map_game_id 1175:', con.execute("SELECT * FROM map_game_info WHERE map_game_id=1175").fetchall())
print('1P_ maps:', con.execute("SELECT * FROM map_game_info WHERE map_name LIKE '1P_%'").fetchall())
