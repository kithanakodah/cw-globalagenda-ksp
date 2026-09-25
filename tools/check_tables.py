import sqlite3
con = sqlite3.connect(r'D:\commonwealth-ga-server-master\out\server.db')
tables = con.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
for t in tables:
    print(t[0])
