function [f, g, h, df, Jg, Jh, p] = coursework_problem(id, x)
    % COURSEWORK_PROBLEM 阶段一保留的独立模型底稿，供主程序回归对照。
    % 输入：id='A'/'B'/'C'；x为原始变量列向量。省略x时返回参考点的值。
    % 输出：f为原目标，g<=0为不等式，h=0为等式；df为目标梯度。
    % Jg/Jh的每一行是一条约束对x的导数；p包含边界、尺度和参考信息。
    % 注意：本底稿C的默认参考点采用文献1e-4等式容差；主程序采用严格参考。
    % 这份文件不是求解器，也不向正式算法注入参考点。
%% 1. 模型元数据与参考信息
    id = upper(char(id));

    switch id
        case 'A'
            p = struct('id', 'A', 'n', 2, 'lb', [-1; -1], 'ub', [2; 2], ...
                'reference_x', [1; 0], 'reference_f', 1, 'f_scale', 1, ...
                'g_scale', ones(3, 1), 'h_scale', zeros(0, 1));

        case 'B'
            p = struct('id', 'B', 'n', 6, 'lb', -ones(6, 1), 'ub', 2*ones(6, 1), ...
                'reference_x', repmat([1; 0], 3, 1), 'reference_f', 3, 'f_scale', 3, ...
                'g_scale', ones(9, 1), 'h_scale', zeros(0, 1));

        case 'C'
            % 文献参考点的等式残差约为1e-4，不能当作严格h=0的可行点。
            p = struct('id', 'C', 'n', 4, 'lb', [0; 0; -.55; -.55], ...
                'ub', [1200; 1200; .55; .55], ...
                'reference_x', [679.945148297028709; 1026.06697600004691; ...
                .118876369094410433; -.39623348521517826], ...
                'reference_f', 5126.4967140071, 'f_scale', 1e4, ...
                'g_scale', ones(2, 1), 'h_scale', 1000*ones(3, 1));

        otherwise
            error('coursework:UnknownProblem', 'Unknown problem ID: %s', id);
    end
    if nargin < 2
        x = p.reference_x;
    end
    validateattributes(x, {'double'}, {'real', 'finite', 'vector', 'numel', p.n});
    x = x(:);

%% 2. 原始模型和解析导数
    switch id
        case 'A'
            % 第4章课内例题：二维凸问题，原题符号统一为g<=0。
            f = (x(1)-2)^2+x(2)^2;
            df = [2*(x(1)-2); 2*x(2)];
            g = [-x(1); -x(2); x(1)^2+x(2)-1];
            Jg = [-1, 0; 0, -1; 2*x(1), 1];
            h = zeros(0, 1);
            Jh = zeros(0, 2);

        case 'B'
            % 六维自建扩展：三组课内约束 + 正弦非凸项 + 相邻组耦合项。
            % 变量顺序为[u1,v1,u2,v2,u3,v3]，L为相邻差平方的矩阵。
            u = x(1:2:end);
            v = x(2:2:end);
            L = [1, -1, 0; -1, 2, -1; 0, -1, 1];
            f = sum((u-2).^2+v.^2+sin(3*pi*u).^2) ...
                +5*sum(diff(u).^2+diff(v).^2);
            df = zeros(6, 1);
            df(1:2:end) = 2*(u-2)+3*pi*sin(6*pi*u)+10*L*u;
            df(2:2:end) = 2*v+10*L*v;
            g = zeros(9, 1);
            Jg = zeros(9, 6);

            for k = 1:3
                cols = 2*k-1:2*k;
                rows = 3*k-2:3*k;
                g(rows) = [-u(k); -v(k); u(k)^2+v(k)-1];
                Jg(rows, cols) = [-1, 0; 0, -1; 2*u(k), 1];
            end
            h = zeros(0, 1);
            Jh = zeros(0, 6);

        case 'C'
            % CEC2006 G05原题；三角函数均使用弧度，保留原始物理量级。
            f = 3*x(1)+1e-6*x(1)^3+2*x(2)+(2e-6/3)*x(2)^3;
            df = [3+3e-6*x(1)^2; 2+2e-6*x(2)^2; 0; 0];
            g = [x(3)-x(4)-.55; x(4)-x(3)-.55];
            Jg = [0, 0, 1, -1; 0, 0, -1, 1];
            a = x(3);
            b = x(4);
            h = [1000*sin(-a-.25)+1000*sin(-b-.25)+894.8-x(1); ...
                1000*sin(a-.25)+1000*sin(a-b-.25)+894.8-x(2); ...
                1000*sin(b-.25)+1000*sin(b-a-.25)+1294.8];
            Jh = [-1, 0, -1000*cos(-a-.25), -1000*cos(-b-.25); ...
                0, -1, 1000*(cos(a-.25)+cos(a-b-.25)), -1000*cos(a-b-.25); ...
                0, 0, -1000*cos(b-a-.25), 1000*(cos(b-.25)+cos(b-a-.25))];
    end
end
