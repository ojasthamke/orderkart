import re
with open(r'C:\Users\ojast\.gemini\antigravity\scratch\orderkart\lib\core\database\database_helper.dart', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'CREATE TABLE' in line and 'workers' in line:
        print(f"Line {i+1}: {line.strip()}")
        # Print next 20 lines
        for j in range(1, 20):
            if i+j < len(lines):
                print(f"Line {i+j+1}: {lines[i+j].strip()}")
