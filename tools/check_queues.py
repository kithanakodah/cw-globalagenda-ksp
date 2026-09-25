import sqlite3
con = sqlite3.connect(r'D:\commonwealth-ga-server-master\out\server.db')
cols = con.execute("PRAGMA table_info(ga_queues)").fetchall()
for c in cols:
    print(c)
print('---')
rows = con.execute("SELECT * FROM ga_queues").fetchall()
for r in rows:
    print(r)
