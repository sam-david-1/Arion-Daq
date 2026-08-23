def check_brackets(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    lines = content.split('\n')
    for i, line in enumerate(lines):
        for j, char in enumerate(line):
            if char in '({[':
                stack.append((char, i+1, j+1))
            elif char in ')}]':
                if not stack:
                    print(f"Extra closing {char} at line {i+1}, col {j+1}")
                    continue
                top, line_num, col_num = stack.pop()
                if (char == ')' and top != '(') or (char == '}' and top != '{') or (char == ']' and top != '['):
                    print(f"Mismatched {char} at line {i+1}, col {j+1} (opened with {top} at line {line_num}, col {col_num})")
                    
    if stack:
        print("Unclosed brackets:")
        for top, line_num, col_num in stack:
            print(f"  {top} at line {line_num}, col {col_num}")

check_brackets(r"c:\Users\SamDa\arion_daq\lib\widgets\zoomable_chart.dart")
