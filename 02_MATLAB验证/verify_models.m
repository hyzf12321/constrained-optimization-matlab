function verify_models
    % VERIFY_MODELS 阶段一独立核查：模型、导数、解析结果和G05参考值。
    % 无输入。需要Optimization Toolbox，仅用于独立调用fmincon交叉核查。
    % 重新运行会更新03_验证结果内同名阶段一输出；不会改round1/round2数据。
    % 正式两套算法不调用本文件的fmincon，也不使用其结果初始化。
%% 1. 准备输出目录、日志和固定随机种子
    root = fileparts(fileparts(mfilename('fullpath')));
    out = fullfile(root, '03_验证结果');

    if ~isfolder(out)
        mkdir(out);
    end
    logPath = fullfile(out, 'phase1_matlab_log.txt');
    logFile = fopen(logPath, 'w');
    assert(logFile ~= -1);
    fclose(logFile);
    diary(logPath);
    cleanup = onCleanup(@() diary('off'));
    fprintf('PHASE1_MODEL_VERIFICATION\nMATLAB=%s\n', version);
    rng(20261025, 'twister');
    gradRows = struct([]);
    ids = {'A', 'B', 'C'};

%% 2. 中心差分检查目标梯度、约束Jacobian和归一化罚函数梯度
    % 每题检查12个一般点和1个参考点，合计39组；全部阈值沿用原验收规则。
    for k = 1:numel(ids)
        id = ids{k};
        [~, ~, ~, ~, ~, ~, p] = coursework_problem(id);
        width = p.ub-p.lb;
        Z = [.1+.8*rand(p.n, 12), (p.reference_x-p.lb)./width];

        for j = 1:size(Z, 2)
            z = Z(:, j);
            x = p.lb+width.*z;
            [f, g, h, df, Jg, Jh] = coursework_problem(id, x);
            assert(isscalar(f) && isfinite(f) && all(isfinite([g; h; df])));
            assert(isequal(size(Jg), [numel(g), p.n]));
            assert(isequal(size(Jh), [numel(h), p.n]));
            step = 1e-6;
            Df = zeros(p.n, 1);
            Dg = zeros(size(Jg));
            Dh = zeros(size(Jh));
            Dphi = zeros(p.n, 1);

            for col = 1:p.n
                dz = zeros(p.n, 1);
                dz(col) = step;
                [fp, gp, hp] = coursework_problem(id, p.lb+width.*(z+dz));
                [fm, gm, hm] = coursework_problem(id, p.lb+width.*(z-dz));
                Df(col) = (fp-fm)/(2*step);
                Dg(:, col) = (gp-gm)/(2*step);
                Dh(:, col) = (hp-hm)/(2*step);

                % max(0,g)^2在g=0处一阶连续、二阶不连续，罚梯度用较小差分步长。
                penaltyStep = 1e-7;
                penaltyDz = zeros(p.n, 1);
                penaltyDz(col) = penaltyStep;
                Dphi(col) = (quadratic_penalty(id, z+penaltyDz, 10) ...
                    -quadratic_penalty(id, z-penaltyDz, 10))/(2*penaltyStep);
            end
            [~, analyticPhi] = quadratic_penalty(id, z, 10);
            errors = [relative_error(Df, width.*df), ...
                relative_error(Dg, Jg.*width'), ...
                relative_error(Dh, Jh.*width'), ...
                relative_error(Dphi, analyticPhi)];
            passed = all(errors(1:3)<1e-6) && errors(4)<2e-5;
            row = struct('Problem', id, 'Point', j, ...
                'ObjectiveGradientError', errors(1), 'InequalityJacobianError', errors(2), ...
                'EqualityJacobianError', errors(3), 'PenaltyGradientError', errors(4), ...
                'Passed', passed);
            gradRows = [gradRows; row]; %#ok<AGROW>
            if ~passed
                fprintf('DERIVATIVE_ERRORS %s %d: %.3e %.3e %.3e %.3e\n', id, j, errors);
            end
            assert(passed, 'Derivative check failed for %s point %d', id, j);
        end
    end
    writetable(struct2table(gradRows), fullfile(out, 'gradient_checks.csv'));
    fprintf('DERIVATIVE_CHECKS=%d PASS\n', numel(gradRows));

%% 3. A/B参考点的KKT条件，以及罚项定义和错误输入的检查
    analytic = struct([]);

    for k = 1:2
        id = ids{k};
        [f, g, h, df, Jg, ~, p] = coursework_problem(id);
        lambda = repmat([0; 1; 1], p.n/2, 1);
        stationarity = norm(df+Jg'*lambda, inf);
        complementarity = max(abs(lambda.*g));
        assert(abs(f-p.reference_f)<1e-12 && max(g) <= 1e-12 && isempty(h));
        assert(stationarity<1e-12 && complementarity<1e-12);
        z = (p.reference_x-p.lb)./(p.ub-p.lb);
        [phi, ~, d] = quadratic_penalty(id, z, 10);
        assert(d.penalty<1e-25 && abs(phi-f/p.f_scale)<1e-12);
        analytic = [analytic; struct('Problem', id, 'Objective', f, ...
            'KKTStationarity', stationarity, 'Complementarity', complementarity)]; %#ok<AGROW>
    end
    [~, ~, ~, ~, ~, ~, pa] = coursework_problem('A');
    badZ = ([1.2; .3]-pa.lb)./(pa.ub-pa.lb);
    [phi1, ~, d1] = quadratic_penalty('A', badZ, 1);
    [phi10, ~, d10] = quadratic_penalty('A', badZ, 10);
    assert(d1.penalty>0 && phi10>phi1 && d10.penalty == d1.penalty);
    assert(abs((phi10-phi1)-9*d1.penalty)<1e-12);
    outsideZ = [-.1; .5];
    [~, ~, outside] = quadratic_penalty('A', outsideZ, 1);
    assert(outside.max_bound>0 && outside.penalty>0);
    rejected = false;

    try
        quadratic_penalty('A', [.5; .5], -1);
    catch
        rejected = true;
    end
    assert(rejected, 'Negative penalty coefficient must be rejected.');
    rejected = false;

    try
        coursework_problem('B', [1; 0]);
    catch
        rejected = true;
    end
    assert(rejected, 'Wrong-dimensional model input must be rejected.');
    writetable(struct2table(analytic), fullfile(out, 'analytic_reference_checks.csv'));
    fprintf('ANALYTIC_KKT_AND_PENALTY_CHECKS=PASS\n');

%% 4. 证明B确有多个非全局严格局部极小点，用于解释局部搜索的局限
    % 这些点仅作分析和检查，禁止注入后续两套算法的初始化。
    localRows = struct([]);
    L = [1, -1, 0; -1, 2, -1; 0, -1, 1];

    for k = 0:2
        qprime = @(t) 2*t-4+3*pi*sin(6*pi*t);
        t = fzero(qprime, [k/3, k/3+1/12]);
        x = repmat([t; 0], 3, 1);
        [f, g, ~, df] = coursework_problem('B', x);
        qsecond = 2+18*pi^2*cos(6*pi*t);
        minEig = min([eig(qsecond*eye(3)+10*L); eig(2*eye(3)+10*L)]);
        assert(max(g) <= 1e-12 && norm(df, inf)<1e-8 && minEig>0 && f>3);
        localRows = [localRows; struct('Basin', k+1, 'u', t, 'v', 0, ...
            'Objective', f, 'GradientInfinityNorm', norm(df, inf), ...
            'MinimumHessianEigenvalue', minEig)]; %#ok<AGROW>
    end
    assert(2-18*pi^2<0);
    writetable(struct2table(localRows), fullfile(out, 'B_local_minima.csv'));
    fprintf('B_THREE_STRICT_LOCAL_MINIMA=PASS\n');

%% 5. G05严格等式参考：多起点SQP与内点法交叉核对
    % 本节允许使用文献点核查参考值；其用途与正式实验的随机初始化不同。
    assert(exist('fmincon', 'file') == 2, 'fmincon is required for this independent audit.');
    opts = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'off', ...
        'SpecifyObjectiveGradient', true, 'SpecifyConstraintGradient', true, ...
        'ConstraintTolerance', 1e-12, 'OptimalityTolerance', 1e-10, ...
        'StepTolerance', 1e-12, 'MaxIterations', 1500, 'MaxFunctionEvaluations', 20000);
    [~, ~, ~, ~, ~, ~, pc] = coursework_problem('C');
    width = pc.ub-pc.lb;
    startZ = [(pc.reference_x-pc.lb)./width, .5*ones(4, 1), rand(4, 10)];
    referenceRows = reference_row('CEC_published', pc.reference_x, NaN, NaN);
    strictX = [];
    strictF = Inf;
    strictCandidates = zeros(0, 4);

    for j = 1:size(startZ, 2)
        [z, ~, flag, output] = fmincon(@objective_c, startZ(:, j), [], [], [], [], ...
            zeros(4, 1), ones(4, 1), @constraints_c, opts);
        x = pc.lb+width.*z;
        row = reference_row(sprintf('strict_sqp_%02d', j), x, flag, output.funcCount);
        referenceRows = [referenceRows; row]; %#ok<AGROW>
        if max([row.MaxInequality, row.MaxEquality, row.MaxBound]) <= 1e-8
            strictCandidates = [strictCandidates; x']; %#ok<AGROW>
            if row.Objective<strictF
                strictF = row.Objective;
                strictX = x;
            end
        end
    end
    assert(~isempty(strictX), 'No acceptable strict G05 reference was found.');
    optsIP = optimoptions(opts, 'Algorithm', 'interior-point');
    [zip, ~, flagIP, outIP] = fmincon(@objective_c, (strictX-pc.lb)./width, ...
        [], [], [], [], zeros(4, 1), ones(4, 1), @constraints_c, optsIP);
    xip = pc.lb+width.*zip;
    rowIP = reference_row('strict_interior_point', xip, flagIP, outIP.funcCount);
    referenceRows = [referenceRows; rowIP];
    assert(max([rowIP.MaxInequality, rowIP.MaxEquality, rowIP.MaxBound]) <= 1e-8 ...
         && abs(rowIP.Objective-strictF)<1e-5);
    [~, strictG, ~, df, ~, Jh] = coursework_problem('C', strictX);
    assert(all(strictG < -1e-6) && all(strictX-pc.lb > 1e-6) ...
         && all(pc.ub-strictX > 1e-6), ...
        'Equality-only KKT check requires inactive inequalities and bounds.');
    mu = -(Jh'\df);
    strictKKT = norm(df+Jh'*mu, inf);
    assert(strictKKT<1e-4, 'Strict G05 reference stationarity is too large.');

%% 6. 复现文献的1e-4等式容差带，解释它与严格参考值的差异
    [zband, ~, flagBand, outBand] = fmincon(@objective_c, (strictX-pc.lb)./width, ...
        [], [], [], [], zeros(4, 1), ones(4, 1), @constraints_c_band, opts);
    xband = pc.lb+width.*zband;
    bandRow = reference_row('relaxed_band_1e-4', xband, flagBand, outBand.funcCount);
    referenceRows = [referenceRows; bandRow];
    assert(bandRow.MaxEquality <= 1.01e-4 && abs(bandRow.Objective-pc.reference_f)<1e-5);
    assert(strictF-pc.reference_f>1e-4);
    writetable(struct2table(referenceRows), fullfile(out, 'G05_reference_checks.csv'));

%% 7. 保存核查数据；通过本节只表示模型与参考核查通过
    strictRow = reference_row('strict_selected', strictX, NaN, NaN);
    summary = struct('phase', 'model_and_reference_verification', ...
        'date', '2026-10-25', 'matlab_version', version, 'random_seed', 20261025, ...
        'derivative_points', numel(gradRows), 'all_derivative_checks_passed', true, ...
        'analytic_checks', analytic, 'B_local_minima', localRows, ...
        'G05_published_x', pc.reference_x', 'G05_published_f', pc.reference_f, ...
        'G05_published_equality_residual', referenceRows(1).MaxEquality, ...
        'G05_strict_x', strictX', 'G05_strict_f', strictF, ...
        'G05_strict_max_equality', strictRow.MaxEquality, ...
        'G05_strict_stationarity', strictKKT, 'G05_strict_mu', mu', ...
        'G05_inequalities_and_bounds_inactive', true, ...
        'G05_inequality_dual_violation', 0, 'G05_complementarity_residual', 0, ...
        'G05_strict_acceptable_runs', size(strictCandidates, 1), ...
        'G05_strict_runs', size(startZ, 2), 'G05_band_x', xband', ...
        'G05_band_f', bandRow.Objective, 'G05_reference_gap', strictF-pc.reference_f, ...
        'main_algorithms_implemented', false, 'all_checks_passed', true);
    fid = fopen(fullfile(out, 'phase1_verification_summary.json'), 'w', 'n', 'UTF-8');
    assert(fid ~= -1);
    fwrite(fid, jsonencode(summary, 'PrettyPrint', true), 'char');
    fclose(fid);
    save(fullfile(out, 'phase1_verification_data.mat'), 'summary', 'gradRows', ...
        'referenceRows', 'localRows', 'strictCandidates');
    fprintf('G05_STRICT_F=%.12f\nG05_STRICT_MAX_H=%.4e\n', strictF, strictRow.MaxEquality);
    fprintf('G05_BAND_F=%.12f\nG05_REFERENCE_GAP=%.8e\n', bandRow.Objective, strictF-pc.reference_f);
    fprintf('G05_STRICT_KKT=%.4e\nALL_PHASE1_CHECKS=PASS\n', strictKKT);
end

function e = relative_error(a, b)
    % 用max(1,解析值幅度)归一化，避免真值接近零时相对误差失真。
    if isempty(a)
        e = 0;
    else
        e = max(abs(a(:)-b(:)))/max(1, max(abs(b(:))));
    end
end

function [f, dfz] = objective_c(z)
    % fmincon回调：原目标缩放，并将原坐标梯度换算为z坐标梯度。
    [~, ~, ~, ~, ~, ~, p] = coursework_problem('C');
    [raw, ~, ~, df] = coursework_problem('C', p.lb+(p.ub-p.lb).*z);
    f = raw/p.f_scale;
    dfz = (p.ub-p.lb).*df/p.f_scale;
end

function [c, e, Jct, Jet] = constraints_c(z)
    % fmincon要求每一列对应一个约束梯度，因此将模型的Jacobian转置。
    [~, ~, ~, ~, ~, ~, p] = coursework_problem('C');
    [~, g, h, ~, Jg, Jh] = coursework_problem('C', p.lb+(p.ub-p.lb).*z);
    c = g./p.g_scale;
    e = h./p.h_scale;
    Jct = (Jg.*(p.ub-p.lb)'./p.g_scale)';
    Jet = (Jh.*(p.ub-p.lb)'./p.h_scale)';
end

function [c, e, Jct, Jet] = constraints_c_band(z)
    % 将等式替换成正负两个不等式，严格复现文献的容差带。
    [c0, h, Jc0, Jh] = constraints_c(z);
    epsilon = 1e-7;
    % 原单位的1e-4除以等式尺度1000。
    c = [c0; h-epsilon; -h-epsilon];
    e = zeros(0, 1);
    Jct = [Jc0, Jh, -Jh];
    Jet = zeros(4, 0);
end

function row = reference_row(label, x, flag, count)
    % 用原始单位记录参考点，包括三个等式的有符号残差。
    [f, g, h, ~, ~, ~, p] = coursework_problem('C', x);
    row = struct('Label', label, 'x1', x(1), 'x2', x(2), 'x3', x(3), 'x4', x(4), ...
        'Objective', f, 'MaxInequality', max([0; g]), 'MaxEquality', max(abs(h)), ...
        'MaxBound', max([0; p.lb-x; x-p.ub]), 'h1', h(1), 'h2', h(2), 'h3', h(3), ...
        'Exitflag', flag, 'FunctionCount', count);
end
