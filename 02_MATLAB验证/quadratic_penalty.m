function [phi, dphi, detail] = quadratic_penalty(id, z, r)
    % QUADRATIC_PENALTY 阶段一独立罚函数底稿，用于核对主程序实现。
    % 输入：id为题号，z为归一化变量，r>0为外罚系数。
    % 输出：phi为缩放目标加二次罚项，dphi为对z的梯度，detail为原始量。
    % 对应课件第4章第119、144页；此函数只评价，不进行任何搜索。
%% 1. 将归一化变量还原到原始坐标
    validateattributes(r, {'double'}, {'real', 'finite', 'scalar', 'positive'});
    [~, ~, ~, ~, ~, ~, p] = coursework_problem(id);
    validateattributes(z, {'double'}, {'real', 'finite', 'vector', 'numel', p.n});
    z = z(:);
    width = p.ub-p.lb;
    x = p.lb+width.*z;
    [f, g, h, df, Jg, Jh] = coursework_problem(id, x);

%% 2. 统一不等式、等式和计算边界
    % 不等式采用max(0,c)^2；等式采用e^2；可行点的罚项为零。
    c = [g./p.g_scale; -z; z-1];
    e = h./p.h_scale;
    Jc = [Jg.*width'./p.g_scale; -eye(p.n); eye(p.n)];
    Je = Jh.*width'./p.h_scale;
    positive = max(0, c);
    penalty = positive'*positive+e'*e;
    phi = f/p.f_scale+r*penalty;

%% 3. 用链式法则计算梯度，保存原始单位下的约束违反量
    dphi = width.*df/p.f_scale+2*r*(Jc'*positive+Je'*e);
    detail = struct('x', x, 'f', f, 'g', g, 'h', h, 'penalty', penalty, ...
        'max_inequality', max([0; g]), 'max_equality', max([0; abs(h)]), ...
        'max_bound', max([0; p.lb-x; x-p.ub]));
end
