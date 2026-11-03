function output = coursework_main(mode)
    % COURSEWORK_MAIN 优化理论与最优控制大作业：统一运行入口。
    % 输入 mode 为下列字符串；不输入时沿用第一轮，避免改变旧用法。
    %   'round1'   ：外罚法 + BFGS 的九个诊断起点，追加保存第一轮批次。
    %   'round2'   ：PSO 自检、两组参数预实验和独立留出验证，追加第二轮批次。
    %   'selftest' ：运行全部算法与模型自检，不保存实验批次。
    %   'summary' / 'plot'   ：查看或绘制第一轮最新结果，不重新求解。
    %   'summary2' / 'plot2' ：查看或绘制第二轮最新结果，不重新求解。
    %   'complex' ：新增课件复合形法及G05等式恢复扩展，追加验证批次。
    %   'summary_complex' / 'plot_complex' ：查看、绘制新增方法的对照结果。
    %   'round3_pilot' ：有限G05诊断、留出验证并冻结第三轮协议。
    %   'round3' ：可续跑的270次主实验、60次多起点、40次敏感性实验及验收。
    %   'summary3' / 'plot3' ：读取第三轮汇总或重新生成报告用图。
    %   'improve_pilot' / 'improve' ：改进方案开发锁参、独立验收及配对对照。
    %   'summary_improved' / 'plot_improved' ：读取改进统计、重建对照图。
    %   'cost_review' / 'summary_cost' / 'plot_cost' ：低成本验证、最终建议表与图。
    %
    % 文件组织：模型、三套方法、验证、实验和绘图均以本地函数分区。
    % 数据统一追加到 03_验证结果/coursework_results.mat；旧批次保持可读取。
    % 核心求解器不调用 fmincon、fminunc 或 particleswarm，不需优化工具箱。
    % 课内主线：二次外罚函数（第4章）+ BFGS（第3章）+ Wolfe 搜索（第1章）。
    % 常用变量：p=模型信息，o=算法参数，x=原变量，z=归一化变量，r=罚系数。
    % f/g/h=原目标/不等式/等式，phi=罚函数，df/Jg/Jh=解析导数，H=逆Hessian近似。
    if nargin == 0
        mode = 'round1';
    end
    root = fileparts(mfilename('fullpath'));
    dataPath = fullfile(root, '03_验证结果', 'coursework_results.mat');

    switch lower(char(mode))
        case 'selftest'
            output = [selftests(root); pso_selftests; complex_selftests; review_selftests; round3_selftests; improvement_selftests];
            disp(struct2table(output));

        case {'cost_review', 'summary_cost'}
            output = cost_entry(root, dataPath, lower(char(mode)));

        case 'plot_cost'
            stored = load(dataPath, 'coursework_results');
            section = stored.coursework_results.improvement;
            output = plot_cost(stored.coursework_results.cost_review, section.batches{section.latest}, root);

        case {'improve_pilot', 'improve', 'summary_improved', 'plot_improved'}
            output = improvement_entry(root, dataPath, lower(char(mode)));

        case 'round3_pilot'
            output = prepare_round3(root, dataPath);

        case 'round3'
            output = run_round3(root, dataPath);

        case {'summary3', 'plot3'}
            stored = load(dataPath, 'coursework_results');
            section = stored.coursework_results.round3;
            output = section.batches{section.latest};
            if strcmpi(mode, 'plot3')
                output = plot_round3(output, root);
            else
                disp(output.summary_main);
                disp(output.summary_multistart);
                disp(output.summary_sensitivity);
                disp(output.checks);
            end

        case 'complex'
            codeReview = review_sources(root);
            tests = [selftests(root); pso_selftests; complex_selftests; review_selftests];
            batch = run_complex_pilots(tests, root);
            batch.code_review = codeReview;
            batch.source_snapshot = fileread([mfilename('fullpath'), '.m']);
            batch.source_version = 'review-v1.0/complex';
            append_complex(dataPath, root, batch);
            output = batch;
            disp(batch.parameter_comparison);
            disp(batch.validation_summary(:, {'Problem', 'Method', 'Seed', ...
                'ObjectiveError', 'MainFeasible', 'TargetReached', 'Evaluations', 'RestorationEvaluations'}));
            disp(batch.checks);
            assert(batch.checks.all_passed, 'coursework:ComplexPilot', ...
                'Complex pilot checks failed; the diagnostic batch has been retained.');

        case {'summary_complex', 'plot_complex'}
            stored = load(dataPath, 'coursework_results');
            section = stored.coursework_results.complex_addition;
            batch = section.batches{section.latest};
            if strcmpi(mode, 'summary_complex')
                disp(batch.parameter_comparison);
                disp(batch.validation_summary(:, {'Problem', 'Method', 'Seed', ...
                    'ObjectiveError', 'MainFeasible', 'TargetReached', 'Evaluations', 'RestorationEvaluations'}));
                disp(batch.checks);
                output = batch;
            else
                output = plot_complex(batch, root);
            end

        case 'round1'
            tests = [selftests(root); review_selftests];
            batch = run_round1(tests);
            batch.source_snapshot = fileread([mfilename('fullpath'), '.m']);
            batch.source_version = 'review-v1.0/round1';

            if isfile(dataPath)
                stored = load(dataPath, 'coursework_results');
                assert(isfield(stored, 'coursework_results'), 'Invalid result file.');
                coursework_results = stored.coursework_results;
            else
                coursework_results = struct('format_version', 1, 'round1', struct('batches', {{}}));
            end
            coursework_results.round1.batches{end+1} = batch;
            coursework_results.round1.latest = numel(coursework_results.round1.batches);

            % 完整保存后再替换文件；此前批次仍保留在同一MAT内。
            tempPath = fullfile(root, '90_临时文件', 'coursework_results_pending.mat');
            save(tempPath, 'coursework_results', '-v7.3');
            [ok, message] = movefile(tempPath, dataPath, 'f');
            assert(ok, message);
            output = batch;
            show_summary(batch);
            fprintf('SAVED_BATCH=%s\nDATA_FILE=%s\n', batch.id, dataPath);

        case 'round2'
            codeReview = review_sources(root);
            tests = [selftests(root); pso_selftests; review_selftests];
            batch = run_round2(tests);
            batch.code_review = codeReview;
            batch.source_snapshot = fileread([mfilename('fullpath'), '.m']);
            batch.source_version = 'review-v1.0/round2';
            append_round2(dataPath, root, batch);
            output = batch;
            show_round2(batch);

        case {'summary2', 'plot2'}
            stored = load(dataPath, 'coursework_results');
            section = stored.coursework_results.round2;
            batch = section.batches{section.latest};

            if strcmpi(mode, 'summary2')
                show_round2(batch);
                output = batch;
            else
                output = plot_round2(batch, root);
            end
        case {'summary', 'plot'}
            stored = load(dataPath, 'coursework_results');
            batch = stored.coursework_results.round1.batches{stored.coursework_results.round1.latest};

            if strcmpi(mode, 'summary')
                show_summary(batch);
                output = batch.summary;
            else
                output = plot_round1(batch, root);
            end
        otherwise
            error('coursework:Mode', ...
                'Use round1, round2, complex, selftest, summary/plot, summary2/plot2, summary_complex/plot_complex.');
    end
end

%% 实验组织：诊断验证、预实验与参数锁定
function review = review_sources(root)
    % 逐个检查现有四个M文件，保存实际使用的底稿快照，便于独立复现。
    files = {'coursework_main.m', ...
        fullfile('02_MATLAB验证', 'coursework_problem.m'), ...
        fullfile('02_MATLAB验证', 'quadratic_penalty.m'), ...
        fullfile('02_MATLAB验证', 'verify_models.m')};
    review = struct('file', {}, 'checkcode_messages', {}, 'source', {});
    for j = 1:numel(files)
        path = fullfile(root, files{j});
        messages = checkcode(path, '-id');
        if ~isempty(messages)
            disp(messages);
        end
        assert(isempty(messages), 'coursework:CodeStyle', ...
            'Resolve Code Analyzer messages in %s before running pilots.', files{j});
        review(j) = struct('file', files{j}, 'checkcode_messages', messages, ...
            'source', fileread(path));
    end
end

function batch = run_complex_pilots(tests, root)
    % 第二轮新增方法预实验：A/B各3个训练起点，C比较两档等式恢复精度。
    % 沿用旧两法的锁定参数；同组留出种子可用于修复前后回归，不重新调参。
    saved = load(fullfile(root, '03_验证结果', 'coursework_results.mat'), 'coursework_results');
    oldSection = saved.coursework_results.round2;
    oldBatch = oldSection.batches{oldSection.latest};
    oldLock = oldBatch.locked_parameters;
    trainingSeeds = 2026102601:2026102603;
    validationSeeds = 2026102641:2026102642;
    tolerances = [1e-6, 1e-8];
    ids = {'A', 'B', 'C'};
    training = cell(0, 1);
    for k = 1:numel(ids)
        p = problem_definition(ids{k});
        for seed = trainingSeeds
            if strcmp(p.id, 'C'), choices = tolerances; else, choices = 1e-8; end
            for tolerance = choices
                o = complex_options(p.id);
                o.h_tolerance = tolerance;
                training{end + 1, 1} = complex_pilot(p, o, seed); %#ok<AGROW>
            end
        end
    end
    rows = struct([]);
    for tolerance = tolerances
        selected = training(cellfun(@(r) strcmp(r.problem, 'C') ...
            && r.options.h_tolerance == tolerance, training));
        row = struct('EqualityTolerance', tolerance, 'Runs', numel(selected), ...
            'Targets', sum(cellfun(@(r) r.metrics.success, selected)), ...
            'StrictFeasible', sum(cellfun(@(r) r.metrics.strict_feasible, selected)), ...
            'TotalEvaluations', sum(cellfun(@(r) r.evaluations, selected)), ...
            'MedianObjectiveError', median(cellfun(@(r) r.metrics.objective_absolute_error, selected)));
        rows = [rows; row]; %#ok<AGROW>
    end
    comparison = struct2table(rows);
    % 达标和严格可行次数相同时优先节约成本，不追逐无实际意义的额外小数位。
    [~, order] = sortrows([-comparison.Targets, -comparison.StrictFeasible, ...
        comparison.TotalEvaluations, comparison.MedianObjectiveError]);
    selectedTolerance = comparison.EqualityTolerance(order(1));
    fprintf('LOCKED_COMPLEX_EQUALITY_TOLERANCE=%.1e\n', selectedTolerance);

    validation = cell(0, 1);
    optionsByProblem = cell(1, 3);
    for k = 1:numel(ids)
        p = problem_definition(ids{k});
        o = complex_options(p.id);
        if strcmp(p.id, 'C'), o.h_tolerance = selectedTolerance; end
        optionsByProblem{k} = o;
        for seed = validationSeeds
            initialStream = RandStream('mt19937ar', 'Seed', seed);
            z0 = rand(initialStream, p.n, 1);
            bfgsOptions = oldLock.bfgs;
            bfgsOptions.max_evaluations = oldLock.evaluation_budgets(k);
            r = exterior_bfgs(p, z0, bfgsOptions);
            r.wolfe_recheck = recheck_wolfe(r.trace, bfgsOptions);
            validation{end + 1, 1} = stamp(r, p, bfgsOptions, seed, z0, 0, NaN); %#ok<AGROW>
            psoOptions = oldLock.pso;
            psoOptions.max_evaluations = oldLock.evaluation_budgets(k);
            r = exterior_pso(p, z0, psoOptions, seed + 100000);
            validation{end + 1, 1} = stamp(r, p, psoOptions, seed, z0, ...
                oldLock.swarm_size, seed + 100000); %#ok<AGROW>
            validation{end + 1, 1} = complex_pilot(p, o, seed); %#ok<AGROW>
        end
    end
    allRuns = [training; validation];
    checks = struct;
    checks.selftests = all([tests.Passed]);
    checks.budgets_respected = all(cellfun(@(r) r.evaluations <= r.options.max_evaluations, allRuns));
    checks.raw_outputs_rechecked = all(cellfun(@check_raw_output, allRuns));
    checks.complete_cost_traces = all(cellfun(@(r) r.trace(end).evaluations == r.evaluations, allRuns));
    checks.complex_feasibility_and_costs = all(cellfun(@check_complex_run, allRuns));
    checks.pso_memory_regression = all(cellfun(@check_pso_history, allRuns));
    checks.bfgs_wolfe_regression = all(cellfun(@(r) ...
        ~strcmp(r.method, 'exterior_penalty_bfgs') || r.wolfe_recheck.violations == 0, allRuns));
    checks.paired_starting_points = true;
    for k = 1:numel(ids)
        for seed = validationSeeds
            group = validation(cellfun(@(r) strcmp(r.problem, ids{k}) ...
                && r.initialization_seed == seed, validation));
            checks.paired_starting_points = checks.paired_starting_points && numel(group) == 3 ...
                && isequal(group{1}.z0, group{2}.z0, group{3}.z0);
        end
    end
    checks.formal_seeds_unused = isempty(intersect(oldLock.formal_seeds, ...
        [trainingSeeds, validationSeeds]));
    checks.G05_has_strict_target = any(cellfun(@(r) strcmp(r.problem, 'C') ...
        && strcmp(r.method, 'complex_direct') && r.metrics.success ...
        && r.metrics.strict_feasible, allRuns));
    checks.all_passed = all(structfun(@(v) logical(v), checks));
    lock = struct('version', 'complex-lock-v1', 'options_by_problem', {optionsByProblem}, ...
        'training_seeds', trainingSeeds, 'validation_seeds', validationSeeds, ...
        'G05_restoration_tolerance', selectedTolerance, 'formal_seeds', oldLock.formal_seeds, ...
        'core_method', 'Course-slide complex reflection with worst/second-worst replacement', ...
        'G05_extension', 'Objective-independent equality restoration using finite-difference Jacobians', ...
        'selection_rule', 'Target count, strict-feasible count, evaluation cost, median error');
    batch = struct('id', char(datetime('now', 'TimeZone', 'Asia/Shanghai', ...
        'Format', 'yyyyMMdd_HHmmss_SSS')), 'phase', 'round2_complex_addition', ...
        'matlab_version', version, 'tests', tests, 'training_runs', {training}, ...
        'validation_runs', {validation}, 'parameter_comparison', comparison, ...
        'training_summary', complex_summary(training), ...
        'validation_summary', complex_summary(validation), 'checks', checks, ...
        'locked_parameters', lock, 'original_methods_parameter_lock', oldLock, ...
        'original_methods_source_batch', oldBatch.id, 'formal_comparison', false);

    function r = stamp(r, p, options, seed, z0, swarmSize, algorithmSeed)
        r.problem = p.id;
        r.phase = 'round2_complex_addition';
        r.initialization_seed = seed;
        r.algorithm_seed = algorithmSeed;
        r.swarm_size = swarmSize;
        r.z0 = z0;
        r.x0 = p.lb + (p.ub - p.lb) .* z0;
        r.options = options;
        r.metrics = quality_metrics(p, r.final_detail);
        fprintf('COMPARISON %s %s seed=%d f=%.11g h=%.2e eval=%d target=%d\n', ...
            p.id, r.method, seed, r.metrics.f, r.metrics.max_h, r.evaluations, r.metrics.success);
    end

    function r = complex_pilot(p, options, seed)
        stream = RandStream('mt19937ar', 'Seed', seed);
        z0 = rand(stream, p.n, 1);
        r = complex_minimize(p, z0, options, seed + 200000);
        r = stamp(r, p, options, seed, z0, NaN, seed + 200000);
    end
end

function T = complex_summary(runs)
    % 完整成本保留在同一表中，恢复成本是联合评价的子集，不再重复相加。
    T = summarize_pilots(runs);
    T.RestorationEvaluations = zeros(height(T), 1);
    T.ConstraintJacobianBuilds = zeros(height(T), 1);
    for j = 1:numel(runs)
        r = runs{j};
        if strcmp(r.method, 'complex_direct')
            T.RestorationEvaluations(j) = r.restoration_evaluations;
            T.ConstraintJacobianBuilds(j) = r.constraint_jacobian_builds;
        end
    end
end

function passed = check_complex_run(r)
    % 独立核查复合形保留顶点的可行性、原目标值、单调历史与恢复成本。
    passed = true;
    if ~strcmp(r.method, 'complex_direct'), return; end
    p = problem_definition(r.problem);
    for j = 1:size(r.vertices, 2)
        d = raw_model_detail(p, r.vertices(:, j));
        passed = passed && complex_feasible(d, r.options) && d.f == r.vertex_values(j);
    end
    passed = passed && all(diff(r.history(:, 3)) <= 0) ...
        && all(diff(r.history(:, 2)) > 0) ...
        && r.history(end, 2) == r.evaluations ...
        && r.restoration_evaluations <= r.evaluations ...
        && r.gradient_evaluations == 0;
    if strcmp(p.id, 'C')
        passed = passed && r.restoration_evaluations > 0 ...
            && r.restoration_evaluations >= 9 * r.constraint_jacobian_builds;
    else
        passed = passed && r.restoration_evaluations == 0 ...
            && r.constraint_jacobian_builds == 0;
    end
end

function append_complex(dataPath, root, batch)
    % 仅追加complex_addition分类；历史round1/round2的原始记录不变。
    stored = load(dataPath, 'coursework_results');
    coursework_results = stored.coursework_results;
    if ~isfield(coursework_results, 'complex_addition')
        coursework_results.complex_addition = struct('batches', {{}});
    end
    section = coursework_results.complex_addition;
    section.batches{end + 1} = batch;
    section.latest = numel(section.batches);
    coursework_results.complex_addition = section;
    temp = fullfile(root, '90_临时文件', 'coursework_results_pending.mat');
    save(temp, 'coursework_results', '-v7.3');
    [ok, message] = movefile(temp, dataPath, 'f');
    assert(ok, message);
    fprintf('SAVED_COMPLEX_BATCH=%s\n', batch.id);
end

function batch = run_round2(tests)
    % 预先规定：3个训练种子比较两组粒子数；选定后用2个新种子验证。
    % 所有记录均保留，失败也保留；留出验证不参与重新挑选参数。
    trainingSeeds = 2026102601:2026102603;
    % 首版总体中位数会掩盖某一题：改为逐题等权，验证种子另取全新集合。
    % 旧批次与旧验证种子2026102611:2026102612保留，均不参与本次锁参。
    validationSeeds = 2026102621:2026102622;
    candidates = [40, 80];
    training = pilot_runs(trainingSeeds, candidates, true);
    comparison = parameter_comparison(training, candidates);
    [~, order] = sortrows([ -comparison.TargetCount, -comparison.FeasibleCount, ...
        comparison.QualityScore, comparison.TotalEvaluations, comparison.SwarmSize]);
    selected = comparison.SwarmSize(order(1));
    fprintf('LOCKED_SWARM_SIZE=%d\n', selected);
    validation = pilot_runs(validationSeeds, selected, true);
    checks = struct;
    checks.selftests = all([tests.Passed]);
    allRuns = [training; validation];
    checks.budgets_respected = all(cellfun(@(r) ...
        r.evaluations <= r.options.max_evaluations, allRuns));
    checks.trace_accounts_for_cost = all(cellfun(@(r) ...
        ~isempty(r.trace) && r.trace(end).evaluations == r.evaluations, allRuns));
    checks.history_and_new_penalty_audits = all(cellfun(@check_pso_history, allRuns));
    checks.raw_outputs_rechecked = all(cellfun(@check_raw_output, allRuns));
    checks.paired_initialization = paired_initialization(allRuns);
    checks.gradient_accounting = all(cellfun(@(r) ...
        (strcmp(r.method, 'exterior_penalty_pso') && r.gradient_evaluations == 0) ...
        || (strcmp(r.method, 'exterior_penalty_bfgs') ...
        && r.gradient_evaluations == r.evaluations), allRuns));
    checks.bfgs_wolfe_regression = all(cellfun(@(r) ...
        ~strcmp(r.method, 'exterior_penalty_bfgs') ...
        || (r.wolfe_recheck.violations == 0 ...
        && r.wolfe_recheck.steps_checked == r.wolfe_steps), allRuns));
    checks.training_validation_disjoint = isempty(intersect(trainingSeeds, validationSeeds));
    checks.all_passed = all(structfun(@(v) logical(v), checks));
    assert(checks.all_passed, 'coursework:Round2', 'Round-2 validation failed.');
    lock = struct('version', 'round2-lock-v2', 'swarm_size', selected, ...
        'pso', pso_options(selected), 'bfgs', default_options, ...
        'problem_ids', {{'A', 'B', 'C'}}, 'evaluation_budgets', [1e5, 3e5, 5e5], ...
        'training_seeds', trainingSeeds, 'validation_seeds', validationSeeds, ...
        'formal_seeds', 2026102701:2026102730, 'formal_runs_per_method', 30, ...
        'selection_rule', ['Lexicographic: target count, feasible count, ' ...
        'mean of per-problem median normalized quality losses, evaluations, smaller swarm.'], ...
        'bfgs_multistart_on_B', true, 'G05_sensitivity_growth_factors', [5, 10, 20], ...
        'no_reference_in_initialization_or_stopping', true, ...
        'formal_comparison_started', false);
    sources = struct('pso_algorithm', ...
        'https://www.mathworks.com/help/gads/particle-swarm-optimization-algorithm.html', ...
        'pso_original_paper', 'https://staff.washington.edu/paymana/swarm/kennedy95-ijcnn.pdf', ...
        'note', ['Self-implemented global-best inertia PSO; not an exact copy of ' ...
        'the adaptive-neighborhood particleswarm solver.']);
    batch = struct('id', char(datetime('now', 'TimeZone', 'Asia/Shanghai', ...
        'Format', 'yyyyMMdd_HHmmss_SSS')), 'phase', 'round2_pilot', ...
        'matlab_version', version, 'tests', tests, 'training_runs', {training}, ...
        'validation_runs', {validation}, 'training_summary', summarize_pilots(training), ...
        'validation_summary', summarize_pilots(validation), ...
        'parameter_comparison', comparison, 'locked_parameters', lock, ...
        'checks', checks, 'sources', sources, 'formal_comparison', false, ...
        'protocol_revision', ['Replaced pooled median by equal-weight per-problem medians. ' ...
        'Prior validation seeds 2026102611:2026102612 are exploratory; ' ...
        'new held-out seeds 2026102621:2026102622 were reserved before rerun.']);
end

function runs = pilot_runs(seeds, candidates, includeBfgs)
    % 两种方法共用每题同一初始点、原始模型、尺度、罚系数序列和评价上限。
    % PSO额外粒子、记忆重评、失败试探均计入各自预算；不调用内置求解器。
    ids = {'A', 'B', 'C'};
    runs = cell(0, 1);

    for problemIndex = 1:numel(ids)
        p = problem_definition(ids{problemIndex});

        for seed = seeds
            initialStream = RandStream('mt19937ar', 'Seed', seed);
            z0 = rand(initialStream, p.n, 1);

            if includeBfgs
                o = experiment_options(p.id, 0);
                run = exterior_bfgs(p, z0, o);
                run.wolfe_recheck = recheck_wolfe(run.trace, o);
                runs{end + 1, 1} = finish(run, o, 0, NaN); %#ok<AGROW>
            end
            for swarmSize = candidates
                o = experiment_options(p.id, swarmSize);
                algorithmSeed = seed + 100000;
                run = exterior_pso(p, z0, o, algorithmSeed);
                runs{end + 1, 1} = finish(run, o, swarmSize, algorithmSeed); %#ok<AGROW>
            end
        end
    end

    function r = finish(r, options, swarmSize, algorithmSeed)
        r.problem = p.id;
        r.phase = 'round2_pilot';
        r.initialization_seed = seed;
        r.algorithm_seed = algorithmSeed;
        r.swarm_size = swarmSize;
        r.z0 = z0;
        r.x0 = p.lb + (p.ub - p.lb) .* z0;
        r.options = options;
        r.metrics = quality_metrics(p, r.final_detail);
        fprintf('PILOT %s %s N=%d seed=%d f=%.10g g+=%.2e h=%.2e eval=%d target=%d\n', ...
            p.id, r.method, swarmSize, seed, r.metrics.f, r.metrics.max_g, ...
            r.metrics.max_h, r.evaluations, r.metrics.success);
    end
end

function o = experiment_options(id, swarmSize)
    % 同题同一硬上限，沿用第一轮上限；实际消耗另外保存，不强行填满预算。
    if swarmSize == 0
        o = default_options;
    else
        o = pso_options(swarmSize);
    end
    switch id
        case 'A'
            o.max_evaluations = 1e5;

        case 'B'
            o.max_evaluations = 3e5;

        case 'C'
            o.max_evaluations = 5e5;
    end
end

function comparison = parameter_comparison(runs, candidates)
    % 先比较达到目标数，再比较可行数；并列时比较归一化质量损失和成本。
    % 质量损失同时考虑目标误差与原始约束违反，数值越低越好。
    rows = struct([]);

    for count = candidates
        selected = runs(cellfun(@(r) r.swarm_size == count, runs));
        loss = zeros(numel(selected), 1);

        for j = 1:numel(selected)
            r = selected{j};
            p = problem_definition(r.problem);
            m = r.metrics;
            violation = max([m.max_g / 1e-6, m.max_h / 1e-4, m.max_bound / 1e-8]);
            loss(j) = log10(1 + m.objective_absolute_error / p.objective_tolerance) ...
                + log10(1 + violation);
        end
        % 每题内部先取中位数，再对三题等权平均，避免某题被总体中位数遮蔽。
        ids = {'A', 'B', 'C'};
        problemLoss = zeros(1, numel(ids));
        for k = 1:numel(ids)
            mask = cellfun(@(r) strcmp(r.problem, ids{k}), selected);
            problemLoss(k) = median(loss(mask));
        end
        row = struct('SwarmSize', count, 'Runs', numel(selected), ...
            'TargetCount', sum(cellfun(@(r) r.metrics.success, selected)), ...
            'FeasibleCount', sum(cellfun(@(r) r.metrics.main_feasible, selected)), ...
            'QualityA', problemLoss(1), 'QualityB', problemLoss(2), ...
            'QualityC', problemLoss(3), 'QualityScore', mean(problemLoss), ...
            'TotalEvaluations', sum(cellfun(@(r) r.evaluations, selected)));
        rows = [rows; row]; %#ok<AGROW>
    end
    comparison = struct2table(rows);
end

function T = summarize_pilots(runs)
    % 每个原始运行一行，完整保留失败；本表不宣称为正式统计结论。
    rows = struct([]);

    for j = 1:numel(runs)
        r = runs{j};
        m = r.metrics;
        method = upper(strrep(r.method, 'exterior_penalty_', ''));
        row = struct('Problem', r.problem, 'Method', method, ...
            'Swarm', r.swarm_size, 'Seed', string(r.initialization_seed), ...
            'Objective', m.f, 'ObjectiveError', m.objective_absolute_error, ...
            'MaxInequality', m.max_g, 'MaxEquality', m.max_h, ...
            'MainFeasible', m.main_feasible, 'StrictFeasible', m.strict_feasible, ...
            'TargetReached', m.success, 'Evaluations', r.evaluations, ...
            'GradientEvaluations', r.gradient_evaluations, ...
            'Seconds', r.seconds, 'Status', r.status);
        rows = [rows; row]; %#ok<AGROW>
    end
    T = struct2table(rows);
end

function passed = check_pso_history(run)
    % 独立重算跨罚系数记忆值，核对每代最优值不增以及完整的重评成本。
    % 这些调用属于事后验证，不向求解器返回信息，也不计入求解预算。
    passed = true;

    if ~strcmp(run.method, 'exterior_penalty_pso')
        return;
    end
    p = problem_definition(run.problem);
    options = struct;
    if isfield(run, 'options'), options = run.options; end

    for k = 1:numel(run.stages)
        s = run.stages(k);
        a = s.memory_audit;

        if k > 1
            passed = passed && a.memory_rechecks == run.swarm_size ...
                && a.current_rechecks == run.swarm_size;
            passed = passed && isequal(a.old_values, run.stages(k - 1).pbest_values) ...
                && isequal(a.memory_positions, run.stages(k - 1).pbest);

            for j = 1:run.swarm_size
                value = search_penalty(p, a.memory_positions(:, j), s.r, options, false);
                passed = passed && abs(value - a.new_memory_values(j)) ...
                    <= 1e-12 * max(1, abs(value));
            end
        end
        for j = 1:run.swarm_size
            value = search_penalty(p, s.pbest(:, j), s.r, options, false);
            passed = passed && abs(value - s.pbest_values(j)) ...
                <= 1e-12 * max(1, abs(value));
        end
        passed = passed && s.history(end, 3) == min(s.pbest_values) ...
            && s.history(1, 2) == run.swarm_size * (1 + (k > 1));
        passed = passed && all(diff(s.history(:, 3)) <= 0) ...
            && all(diff(s.history(:, 2)) > 0) ...
            && s.history(end, 2) == s.evaluations;
    end
end

function passed = check_raw_output(run)
    % 用原变量重算最终函数和约束，检查保存值、可行标志与参考误差。
    p = problem_definition(run.problem);
    [~, ~, d] = penalty_eval(p, run.z, 1, false);
    old = run.final_detail;
    m = quality_metrics(p, d);
    passed = isequal([d.f; d.g; d.h], [old.f; old.g; old.h]) ...
        && isequaln(m, run.metrics) && all(isfinite([d.f; d.g; d.h]));
end

function passed = paired_initialization(runs)
    % 同题同种子的共同起点逐元素相等；PSO第一粒子即该点，其余随机采样。
    passed = true;

    for j = 1:numel(runs)
        r = runs{j};

        if r.swarm_size == 0
            continue;
        end
        match = runs(cellfun(@(a) strcmp(a.problem, r.problem) ...
            && a.initialization_seed == r.initialization_seed && a.swarm_size == 0, runs));
        passed = passed && numel(match) == 1 && isequal(match{1}.z0, r.z0) ...
            && isequal(r.initial_swarm(:, 1), r.z0);
    end
end

function append_round2(dataPath, root, batch)
    % 先完整保存临时MAT，再替换正式文件；保留原round1和全部round2批次。
    stored = load(dataPath, 'coursework_results');
    coursework_results = stored.coursework_results;

    if ~isfield(coursework_results, 'round2')
        coursework_results.round2 = struct('batches', {{}});
    end
    coursework_results.round2.batches{end + 1} = batch;
    coursework_results.round2.latest = numel(coursework_results.round2.batches);
    tempPath = fullfile(root, '90_临时文件', 'coursework_results_pending.mat');
    save(tempPath, 'coursework_results', '-v7.3');
    [ok, message] = movefile(tempPath, dataPath, 'f');
    assert(ok, message);
    fprintf('SAVED_ROUND2_BATCH=%s\n', batch.id);
end

function batch = run_round1(tests)
    % 第一轮诊断：固定起点验证实现；不作为正式30次实验的统计样本。
    opts = default_options;
    cases = { ...
        'A', 'feasible_start', [.2; .2]; ...
        'A', 'infeasible_start', [1.5; 1]; ...
        'A', 'negative_coordinate', [-.5; .8]; ...
        'B', 'mixed_groups', [.15; .1; .45; .2; .75; .15]; ...
        'B', 'upper_region', [.9; .2; .85; .1; .95; .25]; ...
        'B', 'infeasible_mixed', [-.5; .8; .4; -.3; 1.4; .5]; ...
        'C', 'box_midpoint', [600; 600; 0; 0]; ...
        'C', 'asymmetric_start', [300; 900; -.2; .2]; ...
        'C', 'different_angles', [1000; 300; .35; -.35]};
    runs = cell(size(cases, 1), 1);
    rows = struct([]);

    for j = 1:size(cases, 1)
        p = problem_definition(cases{j, 1});

        if strcmp(p.id, 'A')
            opts.max_evaluations = 1e5;
        elseif strcmp(p.id, 'B')
            opts.max_evaluations = 3e5;
        else
            opts.max_evaluations = 5e5;
        end
        x0 = cases{j, 3};
        z0 = (x0-p.lb)./(p.ub-p.lb);
        fprintf('RUN %d/%d: %s %s\n', j, size(cases, 1), p.id, cases{j, 2});
        run = exterior_bfgs(p, z0, opts);
        run.label = cases{j, 2};
        run.phase = 'round1_validation';
        run.x0 = x0;
        run.problem = p.id;
        run.options = opts;
        run.metrics = quality_metrics(p, run.final_detail);
        run.wolfe_recheck = recheck_wolfe(run.trace, opts);
        runs{j} = run;
        m = run.metrics;
        rows = [rows; struct('Problem', p.id, 'Start', run.label, 'Objective', m.f, ...
            'ObjectiveError', m.objective_absolute_error, 'MaxInequality', m.max_g, ...
            'MaxEquality', m.max_h, 'MaxBound', m.max_bound, ...
            'MainFeasible', m.main_feasible, 'StrictFeasible', m.strict_feasible, ...
            'TargetReached', m.success, 'Evaluations', run.evaluations, ...
            'GradientEvaluations', run.gradient_evaluations, 'Seconds', run.seconds, ...
            'OuterIterations', numel(run.stages), 'WolfeSteps', run.wolfe_steps, ...
            'LineFailures', run.line_failures, 'Status', run.status)]; %#ok<AGROW>
        fprintf('  f=%.12g g+=%.2e |h|=%.2e eval=%d status=%s\n', ...
            m.f, m.max_g, m.max_h, run.evaluations, run.status);
    end
    T = struct2table(rows);
    checks = struct;
    checks.selftests = all([tests.Passed]);
    checks.all_runs_finite = all(isfinite(T.Objective));
    checks.budgets_respected = all(cellfun(@(r) r.evaluations <= r.options.max_evaluations, runs));
    checks.all_accepted_steps_strong_wolfe = all(cellfun(@(r) ...
        r.wolfe_violations == 0 && r.wolfe_recheck.violations == 0 ...
        && r.wolfe_recheck.steps_checked == r.wolfe_steps, runs));
    checks.trace_accounts_for_terminal_trials = all(cellfun(@(r) ...
        r.trace(end).evaluations == r.evaluations, runs));
    checks.foundation_all_targets = all(T.TargetReached(strcmp(T.Problem, 'A')));
    checks.extension_has_feasible_stationary_run = any(cellfun(@(r) ...
        strcmp(r.problem, 'B') && r.metrics.main_feasible && r.kkt.stationarity_relative <= 1e-5, runs));
    checks.challenge_has_strict_target = any(T.TargetReached(strcmp(T.Problem, 'C')) ...
        & T.StrictFeasible(strcmp(T.Problem, 'C')));
    checks.extension_non_global_points_have_positive_curvature = all(cellfun(@(r) ...
        ~strcmp(r.problem, 'B') || r.metrics.success ...
        || r.metrics.objective_hessian_min_eigenvalue>0, runs));
    checks.all_passed = all(structfun(@(v) logical(v), checks));
    batch = struct('id', char(datetime('now', 'TimeZone', 'Asia/Shanghai', ...
        'Format', 'yyyyMMdd_HHmmss_SSS')), 'phase', 'round1_validation', ...
        'matlab_version', version, 'tests', tests, 'runs', {runs}, 'summary', T, ...
        'checks', checks, 'selftest_seed', 20261025, 'formal_comparison', false, ...
        'notes', 'Nine diagnostic starts; not a 30-run performance comparison.');
end

%% 第三轮：固定协议、有限诊断、正式实验及统一验收
function candidates = round3_candidates
    % 仅改变跨层多样性；不引入梯度、可行性恢复或其他目标精修算法。
    candidates = struct('name', {'baseline', 'radius_quarter', 'radius_constant', 'retain_swarm'}, ...
        'radius_power', {.5, .25, 0, .5}, 'transition_mode', {'cloud', 'cloud', 'cloud', 'retain'});
end

function o = round3_options(protocol, id, method, shape, candidate)
    index = find(strcmp({'A', 'B', 'C'}, id));
    if strcmp(method, 'COMPLEX')
        o = protocol.complex_options{index};
        o.max_evaluations = protocol.budgets(index);
        return;
    end
    if strcmp(method, 'BFGS')
        o = protocol.bfgs;
    else
        o = protocol.pso;
        choices = round3_candidates;
        if nargin < 5
            candidate = 1;
            if strcmp(id, 'C'), candidate = protocol.selected_candidate; end
        end
        o.radius_power = choices(candidate).radius_power;
        o.transition_mode = choices(candidate).transition_mode;
        o.boundary_mode = 'penalty';
    end
    o.max_evaluations = protocol.budgets(index);
    o.r_schedule = 10 .^ (10 * linspace(0, 1, 11).^shape);
    o.max_outer = numel(o.r_schedule);
end

function batch = prepare_round3(root, dataPath)
    stored = load(dataPath, 'coursework_results');
    assert(~isfield(stored.coursework_results, 'round3'), 'coursework:AlreadyPrepared', ...
        'Round 3 is already prepared. Use round3 to resume; do not retune on formal results.');
    codeReview = review_sources(root);
    tests = [selftests(root); pso_selftests; complex_selftests; review_selftests; round3_selftests];
    old = stored.coursework_results.round2;
    original = old.batches{old.latest}.locked_parameters;
    section = stored.coursework_results.complex_addition;
    complexLock = section.batches{section.latest}.locked_parameters;
    protocol = struct('version', 'round3-lock-v1', 'budgets', original.evaluation_budgets, ...
        'bfgs', original.bfgs, 'pso', original.pso, ...
        'complex_options', {complexLock.options_by_problem}, 'selected_candidate', 1, ...
        'formal_seeds', original.formal_seeds, 'training_seeds', 2026102661:2026102663, ...
        'holdout_seeds', 2026102671:2026102673, 'sensitivity_seeds', original.formal_seeds(1:10), ...
        'schedule_shapes', [2, 1, .5], 'schedule_names', {{'slow', 'current', 'fast'}}, ...
        'multistart_count', 40, 'main_count', 270, 'multistart_count_runs', 60, ...
        'sensitivity_count', 40, 'boundary_rule', 'Common exterior penalty; no PSO position clipping', ...
        'pilot_selection', 'Success count, feasible count, median absolute error, evaluation cost', ...
        'timing', 'Solver-only wall time; postchecks/checkpoints excluded; randomized job order; warmup separate');
    assert(isempty(intersect(protocol.formal_seeds, [protocol.training_seeds, protocol.holdout_seeds])));
    choices = round3_candidates;
    training = cell(0, 1);
    for c = 1:numel(choices)
        for seed = protocol.training_seeds
            o = round3_options(protocol, 'C', 'PSO', 1, c);
            training{end + 1, 1} = execute_round3('C', 'PSO', seed, o, choices(c).name); %#ok<AGROW>
        end
    end
    rows = struct([]);
    for c = 1:numel(choices)
        group = training(cellfun(@(r) strcmp(r.variant, choices(c).name), training));
        rows(c).Candidate = choices(c).name;
        rows(c).Successes = sum(cellfun(@(r) r.metrics.success, group));
        rows(c).Feasible = sum(cellfun(@(r) r.metrics.main_feasible, group));
        rows(c).MedianError = median(cellfun(@(r) r.metrics.objective_absolute_error, group));
        rows(c).TotalEvaluations = sum(cellfun(@(r) r.evaluations, group));
    end
    comparison = struct2table(rows);
    [~, order] = sortrows([-comparison.Successes, -comparison.Feasible, ...
        comparison.MedianError, comparison.TotalEvaluations]);
    protocol.selected_candidate = order(1);
    % 留出集合只验证已选方案和基线，不能根据留出结果再次挑参数。
    holdout = cell(0, 1);
    for c = reshape(unique([1, order(1)], 'stable'), 1, [])
        for seed = protocol.holdout_seeds
            o = round3_options(protocol, 'C', 'PSO', 1, c);
            holdout{end + 1, 1} = execute_round3('C', 'PSO', seed, o, choices(c).name); %#ok<AGROW>
        end
    end
    batch = struct('id', char(datetime('now', 'TimeZone', 'Asia/Shanghai', ...
        'Format', 'yyyyMMdd_HHmmss_SSS')), 'source_version', 'round3-v1.0', ...
        'phase', 'round3', 'status', 'locked', 'formal_comparison', false, ...
        'matlab_version', version, 'protocol', protocol, 'tests', tests, 'code_review', codeReview, ...
        'source_snapshot', fileread(fullfile(root, 'coursework_main.m')), ...
        'pilot_training', {training}, 'pilot_holdout', {holdout}, 'pilot_comparison', comparison, ...
        'main_runs', {cell(0, 1)}, 'multistart_runs', {cell(0, 1)}, ...
        'sensitivity_runs', {cell(0, 1)}, 'warmup_runs', {cell(0, 1)});
    save_round3(dataPath, root, batch);
    disp(comparison);
    fprintf('ROUND3_LOCKED=%s CANDIDATE=%s FORMAL_RUNS=0\n', batch.id, choices(order(1)).name);
end

function r = execute_round3(id, method, seed, o, variant, initialPoint)
    % 所有方法接收同一个随机起点；不同算法随机流分开，且不改全局rng。
    p = problem_definition(id);
    if nargin < 6
        stream = RandStream('mt19937ar', 'Seed', seed);
        z0 = rand(stream, p.n, 1);
    else
        z0 = initialPoint;
    end
    switch method
        case 'BFGS'
            r = exterior_bfgs(p, z0, o);
            algorithmSeed = NaN;
            r.wolfe_recheck = recheck_wolfe(r.trace, o);
        case 'PSO'
            algorithmSeed = seed + 100000;
            r = exterior_pso(p, z0, o, algorithmSeed);
        case 'COMPLEX'
            algorithmSeed = seed + 200000;
            r = complex_minimize(p, z0, o, algorithmSeed);
        otherwise
            error('coursework:Method', 'Unknown method.');
    end
    r.problem = id;
    r.base_method = method;
    r.variant = variant;
    r.phase = 'round3';
    r.initialization_seed = seed;
    r.algorithm_seed = algorithmSeed;
    r.z0 = z0;
    r.x0 = p.lb + (p.ub - p.lb) .* z0;
    r.options = o;
    r.swarm_size = 0;
    if strcmp(method, 'PSO'), r.swarm_size = o.swarm_size; end
    r.metrics = quality_metrics(p, r.final_detail);
    r.verified = round3_check_run(r);
    assert(r.verified, 'coursework:Round3Run', 'Raw data/cost audit failed.');
    if ~isfield(o, 'quiet') || ~o.quiet
        fprintf('ROUND3 %s %s %s seed=%d f=%.11g error=%.3g feasible=%d target=%d eval=%d\n', ...
            id, method, variant, seed, r.metrics.f, r.metrics.objective_absolute_error, ...
            r.metrics.main_feasible, r.metrics.success, r.evaluations);
    end
end

function passed = round3_check_run(r)
    r = unpack_trace_record(r); % 新子轨迹采用无损列式存储，兼容旧逐点结构体。
    passed = check_raw_output(r) && r.evaluations <= r.options.max_evaluations ...
        && ~isempty(r.trace) && r.trace(end).evaluations == r.evaluations;
    if isfield(r, 'restarts')
        passed = passed && sum(cellfun(@(s) s.evaluations, r.restarts)) == r.evaluations ...
            && all(cellfun(@round3_check_run, r.restarts));
    elseif strcmp(r.base_method, 'PSO')
        passed = passed && check_pso_history(r) && r.gradient_evaluations == 0 ...
            && all([r.stages.boundary_repairs] == 0);
    elseif strcmp(r.base_method, 'BFGS')
        passed = passed && r.wolfe_recheck.violations == 0 ...
            && r.wolfe_recheck.steps_checked == r.wolfe_steps;
    else
        passed = passed && check_complex_run(r);
    end
end

function save_round3(dataPath, root, batch)
    % 原有阶段完全保留；仅更新本轮尚在执行的批次，先完整落盘再替换。
    stored = load(dataPath, 'coursework_results');
    coursework_results = stored.coursework_results;
    if ~isfield(coursework_results, 'round3')
        coursework_results.round3 = struct('batches', {{batch}}, 'latest', 1);
    else
        section = coursework_results.round3;
        assert(strcmp(section.batches{section.latest}.id, batch.id));
        coursework_results.round3.batches{section.latest} = batch;
    end
    pending = fullfile(root, '90_临时文件', 'coursework_results_pending.mat');
    save(pending, 'coursework_results', '-v7.3');
    [ok, message] = movefile(pending, dataPath, 'f');
    assert(ok, message);
end

function batch = run_round3(root, dataPath)
    stored = load(dataPath, 'coursework_results');
    assert(isfield(stored.coursework_results, 'round3'), 'Run round3_pilot first.');
    section = stored.coursework_results.round3;
    batch = section.batches{section.latest};
    if strcmp(batch.status, 'complete')
        disp(batch.summary_main);
        return;
    end
    assert(strcmp(batch.source_snapshot, fileread(fullfile(root, 'coursework_main.m'))), ...
        'coursework:FrozenSource', 'The frozen source has changed. Review before resuming.');
    protocol = batch.protocol;
    ids = {'A', 'B', 'C'};
    methods = {'BFGS', 'PSO', 'COMPLEX'};
    batch.status = 'running';
    % 三题三法均先预热；结果单列，编译开销不混入正式记录。
    if isempty(batch.warmup_runs)
        for k = 1:3
            for m = 1:3
                o = round3_options(protocol, ids{k}, methods{m}, 1);
                o.max_evaluations = 3000;
                batch.warmup_runs{end + 1, 1} = execute_round3(ids{k}, methods{m}, ...
                    2026102680 + k, o, 'warmup');
            end
        end
        save_round3(dataPath, root, batch);
    end
    jobs = zeros(0, 3);
    for k = 1:3
        for seed = protocol.formal_seeds
            for m = 1:3, jobs(end + 1, :) = [k, m, seed]; end %#ok<AGROW>
        end
    end
    stream = RandStream('mt19937ar', 'Seed', 2026102690);
    jobs = jobs(randperm(stream, size(jobs, 1)), :);
    for j = numel(batch.main_runs) + 1:size(jobs, 1)
        job = jobs(j, :);
        o = round3_options(protocol, ids{job(1)}, methods{job(2)}, 1);
        batch.main_runs{j, 1} = execute_round3(ids{job(1)}, methods{job(2)}, job(3), o, 'main');
        if mod(j, 10) == 0 || j == size(jobs, 1)
            batch.formal_comparison = true;
            save_round3(dataPath, root, batch);
            fprintf('CHECKPOINT main=%d/270\n', j);
        end
    end
    for j = numel(batch.multistart_runs) + 1:60
        method = methods{1 + 2 * (mod(j - 1, 2))};
        seed = protocol.formal_seeds(ceil(j / 2));
        batch.multistart_runs{j, 1} = round3_multistart(protocol, method, seed);
        if mod(j, 10) == 0, save_round3(dataPath, root, batch); end
    end
    jobs = zeros(0, 3);
    for shape = [2, .5]
        for seed = protocol.sensitivity_seeds
            for m = 1:2, jobs(end + 1, :) = [shape, m, seed]; end %#ok<AGROW>
        end
    end
    for j = numel(batch.sensitivity_runs) + 1:size(jobs, 1)
        shape = jobs(j, 1);
        o = round3_options(protocol, 'C', methods{jobs(j, 2)}, shape);
        name = 'slow';
        if shape == .5, name = 'fast'; end
        batch.sensitivity_runs{j, 1} = execute_round3('C', methods{jobs(j, 2)}, jobs(j, 3), o, name);
        if mod(j, 10) == 0, save_round3(dataPath, root, batch); end
    end
    batch.reproduction_checks = reproduce_round3(batch);
    batch = analyze_round3(batch);
    batch.status = 'complete';
    batch.completed_at = char(datetime('now', 'TimeZone', 'Asia/Shanghai'));
    save_round3(dataPath, root, batch);
    batch.figure_paths = plot_round3(batch, root);
    save_round3(dataPath, root, batch);
    disp(batch.summary_main);
    disp(batch.summary_multistart);
    disp(batch.summary_sensitivity);
    disp(batch.checks);
end

function r = round3_multistart(protocol, method, seed)
    % 固定40个起点；每次最多总上限/40，不以已知目标决定何时停止重启。
    % 总上限与B题主实验相同，提前结束子运行的节省以实际调用数如实报告。
    p = problem_definition('B');
    o = round3_options(protocol, 'B', method, 1);
    budget = o.max_evaluations;
    stream = RandStream('mt19937ar', 'Seed', seed);
    z0 = rand(stream, p.n, 1);
    restartStream = RandStream('mt19937ar', 'Seed', seed + 300000);
    total = 0;
    gradients = 0;
    restarts = cell(protocol.multistart_count, 1);
    best = [];
    trace = struct([]);
    solverSeconds = 0;
    timer = tic;
    for j = 1:protocol.multistart_count
        local = o;
        local.max_evaluations = floor(budget / protocol.multistart_count);
        point = z0;
        if j > 1, point = rand(restartStream, p.n, 1); end
        if strcmp(method, 'BFGS')
            s = exterior_bfgs(p, point, local);
            s.wolfe_recheck = recheck_wolfe(s.trace, local);
        else
            s = complex_minimize(p, point, local, seed + 200000 + 1000*j);
        end
        solverSeconds = solverSeconds + s.seconds;
        s.problem = 'B';
        s.base_method = method;
        s.z0 = point;
        s.options = local;
        s.swarm_size = 0;
        s.metrics = quality_metrics(p, s.final_detail);
        total = total + s.evaluations;
        gradients = gradients + s.gradient_evaluations;
        restarts{j} = s;
        if isempty(best) || prefer_raw(s.final_detail, best.final_detail, p)
            best = s;
        end
        d = best.final_detail;
        trace = [trace; struct('evaluations', total, 'f', d.f, 'max_g', d.max_g, ...
            'max_h', d.max_h, 'max_bound', d.max_bound, 'z', best.z)]; %#ok<AGROW>
    end
    r = struct('method', ['multistart_', lower(method)], 'base_method', method, ...
        'variant', '40starts', 'problem', 'B', 'phase', 'round3', ...
        'initialization_seed', seed, 'z0', z0, 'options', o, 'z', best.z, ...
        'final_detail', best.final_detail, 'metrics', best.metrics, ...
        'evaluations', total, 'gradient_evaluations', gradients, ...
        'seconds', solverSeconds, 'wall_seconds', toc(timer), ...
        'trace', trace, 'status', sprintf('fixed_%d_starts', protocol.multistart_count), ...
        'restarts', {restarts}, 'swarm_size', 0);
    r.verified = round3_check_run(r);
    assert(r.verified, 'Multistart accounting failed.');
    fprintf('MULTISTART B %s seed=%d target=%d eval=%d\n', method, seed, r.metrics.success, total);
end

function yes = prefer_raw(a, b, p)
    % 多起点结果按原始可行性选优；两者都不可行时比较归一化违反量。
    va = raw_violation(p, a.max_g, a.max_h, a.max_bound);
    vb = raw_violation(p, b.max_g, b.max_h, b.max_bound);
    if va <= 1 && vb <= 1
        yes = a.f < b.f;
    elseif va <= 1 || vb <= 1
        yes = va <= 1;
    else
        yes = va < vb;
    end
end

function checks = reproduce_round3(batch)
    % 每题每法重新运行同一个正式种子，比较全部运行字段，仅排除计时。
    rows = struct([]);
    seed = batch.protocol.formal_seeds(1);
    for id = {'A', 'B', 'C'}
        for method = {'BFGS', 'PSO', 'COMPLEX'}
            mask = cellfun(@(r) strcmp(r.problem, id{1}) && strcmp(r.base_method, method{1}) ...
                && r.initialization_seed == seed, batch.main_runs);
            prior = batch.main_runs{find(mask, 1)};
            repeated = execute_round3(id{1}, method{1}, seed, prior.options, 'main');
            row = struct('Problem', id{1}, 'Method', method{1}, 'Seed', seed, ...
                'IdenticalExceptTime', isequaln(rmfield(prior, 'seconds'), rmfield(repeated, 'seconds')), ...
                'Evaluations', repeated.evaluations);
            rows = [rows; row]; %#ok<AGROW>
        end
    end
    checks = struct2table(rows);
    assert(all(checks.IdenticalExceptTime), 'coursework:Reproduction', 'Seed reproduction failed.');
end

function v = raw_violation(p, g, h, bound)
    hTolerance = 1e-6;
    if strcmp(p.id, 'C'), hTolerance = 1e-4; end
    v = max([g / 1e-6; h / hTolerance; bound / 1e-8], [], 1);
end

function batch = analyze_round3(batch)
    % 表格先区分可行与达标；目标精度分布只在可行输出上汇总。
    batch.table_main = round3_table(batch.main_runs);
    batch.table_multistart = round3_table(batch.multistart_runs);
    baseline = batch.main_runs(cellfun(@(r) strcmp(r.problem, 'B'), batch.main_runs));
    batch.summary_main = round3_statistics(batch.main_runs);
    batch.summary_multistart = round3_statistics([baseline; batch.multistart_runs]);
    baseline = batch.main_runs(cellfun(@(r) strcmp(r.problem, 'C') ...
        && ~strcmp(r.base_method, 'COMPLEX') ...
        && ismember(r.initialization_seed, batch.protocol.sensitivity_seeds), batch.main_runs));
    for j = 1:numel(baseline), baseline{j}.variant = 'current'; end
    batch.table_sensitivity = round3_table([baseline; batch.sensitivity_runs]);
    batch.summary_sensitivity = round3_statistics([baseline; batch.sensitivity_runs]);
    allRuns = [batch.main_runs; batch.multistart_runs; batch.sensitivity_runs];
    checks = struct('main_count_270', numel(batch.main_runs) == 270, ...
        'multistart_count_60', numel(batch.multistart_runs) == 60, ...
        'sensitivity_count_40', numel(batch.sensitivity_runs) == 40, ...
        'all_raw_cost_and_algorithm_checks', all(cellfun(@round3_check_run, allRuns)), ...
        'paired_main_starts', true, 'common_penalty_options', true, ...
        'schedule_endpoints_and_layers', true, ...
        'nine_reproductions_identical', all(batch.reproduction_checks.IdenticalExceptTime), ...
        'no_formal_training_overlap', isempty(intersect(batch.protocol.formal_seeds, ...
        [batch.protocol.training_seeds, batch.protocol.holdout_seeds])));
    for id = {'A', 'B', 'C'}
        for seed = batch.protocol.formal_seeds
            group = batch.main_runs(cellfun(@(r) strcmp(r.problem, id{1}) ...
                && r.initialization_seed == seed, batch.main_runs));
            checks.paired_main_starts = checks.paired_main_starts && numel(group) == 3 ...
                && isequal(group{1}.z0, group{2}.z0, group{3}.z0);
            pair = group(cellfun(@(r) ~strcmp(r.base_method, 'COMPLEX'), group));
            checks.common_penalty_options = checks.common_penalty_options ...
                && isequal(pair{1}.options.r_schedule, pair{2}.options.r_schedule) ...
                && pair{1}.options.max_evaluations == pair{2}.options.max_evaluations;
        end
    end
    for j = 1:numel(allRuns)
        r = allRuns{j};
        if strcmp(r.base_method, 'COMPLEX'), continue; end
        sequence = r.options.r_schedule;
        checks.schedule_endpoints_and_layers = checks.schedule_endpoints_and_layers ...
            && numel(sequence) == 11 && sequence(1) == 1 && sequence(end) == 1e10 ...
            && all(diff(sequence) > 0);
    end
    checks.all_passed = all(structfun(@(v) logical(v), checks));
    batch.checks = checks;
    assert(checks.all_passed, 'coursework:Round3Audit', 'Round 3 audit failed.');
end

function T = round3_table(runs)
    rows = struct([]);
    for j = 1:numel(runs)
        r = runs{j};
        m = r.metrics;
        p = problem_definition(r.problem);
        jacobians = 0;
        restoration = 0;
        if isfield(r, 'constraint_jacobian_builds'), jacobians = r.constraint_jacobian_builds; end
        if isfield(r, 'restoration_evaluations'), restoration = r.restoration_evaluations; end
        rows(j).Problem = r.problem;
        rows(j).Method = r.base_method;
        rows(j).Variant = r.variant;
        rows(j).Seed = r.initialization_seed;
        rows(j).Objective = m.f;
        rows(j).AbsError = m.objective_absolute_error;
        rows(j).SignedError = m.objective_signed_error;
        rows(j).Feasible = m.main_feasible;
        rows(j).StrictFeasible = m.strict_feasible;
        rows(j).Success = m.success;
        rows(j).Evaluations = r.evaluations;
        rows(j).Gradients = r.gradient_evaluations;
        rows(j).JacobianBuilds = jacobians;
        rows(j).RestorationEvaluations = restoration;
        rows(j).Seconds = r.seconds;
        rows(j).Status = r.status;
        rows(j).NormalizedViolation = raw_violation(p, m.max_g, m.max_h, m.max_bound);
    end
    T = struct2table(rows);
end

function summary = round3_statistics(runs)
    T = round3_table(runs);
    keys = unique(strcat(string(T.Problem), '|', string(T.Method), '|', string(T.Variant)), 'stable');
    rows = struct([]);
    for k = 1:numel(keys)
        mask = strcat(string(T.Problem), '|', string(T.Method), '|', string(T.Variant)) == keys(k);
        group = T(mask, :);
        feasible = group.AbsError(group.Feasible);
        if isempty(feasible), feasible = NaN; end
        rows(k).Problem = group.Problem{1};
        rows(k).Method = group.Method{1};
        rows(k).Variant = group.Variant{1};
        rows(k).Runs = height(group);
        rows(k).FeasibleRuns = sum(group.Feasible);
        rows(k).StrictRuns = sum(group.StrictFeasible);
        rows(k).Successes = sum(group.Success);
        rows(k).MedianObjective = median(group.Objective(group.Feasible));
        rows(k).MedianError = median(feasible);
        rows(k).MeanError = mean(feasible);
        rows(k).StdError = std(feasible);
        rows(k).ErrorIQR = sample_quantile(feasible, .75) - sample_quantile(feasible, .25);
        rows(k).BestError = min(feasible);
        rows(k).WorstError = max(feasible);
        rows(k).MedianEval = median(group.Evaluations);
        rows(k).EvalIQR = sample_quantile(group.Evaluations, .75) - sample_quantile(group.Evaluations, .25);
        rows(k).MedianSeconds = median(group.Seconds);
        rows(k).MedianGradients = median(group.Gradients);
        rows(k).MedianJacobians = median(group.JacobianBuilds);
        rows(k).MedianRestoration = median(group.RestorationEvaluations);
    end
    summary = struct2table(rows);
    summary = sortrows(summary, {'Problem', 'Method', 'Variant'});
end

function q = sample_quantile(values, probability)
    % 线性插值分位数，无需Statistics and Machine Learning Toolbox。
    values = sort(values(isfinite(values)));
    if isempty(values), q = NaN; return; end
    position = 1 + (numel(values) - 1) * probability;
    lo = floor(position);
    hi = ceil(position);
    q = values(lo) + (position - lo) * (values(hi) - values(lo));
end

function tests = round3_selftests
    tests = struct([]);
    o = pso_options(12);
    o.boundary_mode = 'penalty';
    o.max_evaluations = 12000;
    o.max_generations = 999;
    a = pso_minimize(@outside_test, .5, o, RandStream('mt19937ar', 'Seed', 199), []);
    tests = check(tests, 'Round3_PSO_can_search_outside_box', abs(a.z - 1.3) < 1e-5 ...
        && a.boundary_repairs == 0, a.z);
    b = pso_minimize(@outside_test, .5, o, RandStream('mt19937ar', 'Seed', 199), []);
    tests = check(tests, 'Round3_unclipped_PSO_reproducible', isequal(a.history, b.history), a.evaluations);
    for shape = [2, 1, .5]
        o.r_schedule = 10 .^ (10 * linspace(0, 1, 11).^shape);
        assert(penalty_parameter(o, 1) == 1 && penalty_parameter(o, 11) == 1e10);
    end
    tests = check(tests, 'Round3_schedules_fixed_endpoints', true, 11);
    p = problem_definition('A');
    o = pso_options(12);
    o.boundary_mode = 'penalty';
    o.transition_mode = 'retain';
    o.r_schedule = [1, 10, 100];
    o.max_outer = 3;
    o.max_evaluations = 3000;
    o.swarm_size = 12;
    r = exterior_pso(p, [.4; .4], o, 211);
    r.problem = 'A';
    r.swarm_size = 12;
    tests = check(tests, 'Round3_retain_memory_and_budget', check_pso_history(r) ...
        && r.trace(end).evaluations == r.evaluations && r.evaluations <= 3000, r.evaluations);
    tests = check(tests, 'Round3_quantile', sample_quantile([1, 2, 3, 4], .25) == 1.75, 1.75);
    % 用缩小预算覆盖多起点真实调用、成本聚合及统计表，不只检查包装层。
    protocol = struct('budgets', [1e5, 4000, 5e5], 'bfgs', default_options, ...
        'pso', pso_options(40), 'complex_options', {{complex_options('A'), ...
        complex_options('B'), complex_options('C')}}, 'multistart_count', 4);
    first = round3_multistart(protocol, 'BFGS', 223);
    second = round3_multistart(protocol, 'COMPLEX', 223);
    tests = check(tests, 'Round3_multistart_budget_and_selection', first.verified ...
        && second.verified && first.evaluations <= 4000 && second.evaluations <= 4000 ...
        && numel(first.restarts) == 4 && numel(second.restarts) == 4, first.evaluations);
    summary = round3_statistics({first; second});
    tests = check(tests, 'Round3_statistics_real_runs', height(summary) == 2 ...
        && all(summary.Runs == 1) && sum(summary.MedianEval) == first.evaluations + second.evaluations, height(summary));
    fprintf('ROUND3_SELFTESTS=%d PASS\n', numel(tests));
end

function [f, gradient, d] = outside_test(z)
    f = sum((z - 1.3).^2);
    gradient = [];
    d = struct('f', f, 'max_g', 0, 'max_h', 0, 'max_bound', 0, 'x', z);
end

%% 课内传统方法：外罚函数、BFGS与强Wolfe搜索
%% 改进用的共同坐标预处理与直接法可行投影（不改变原问题）
function o = improved_options(protocol, id, method, candidate)
    if nargin < 4, candidate = protocol.selected_candidate; end
    o = round3_options(protocol.baseline_protocol, id, method, 1);
    if strcmp(id, 'C') && ~strcmp(method, 'COMPLEX')
        o.coordinates = 'G05_residual';
        if strcmp(method, 'PSO')
            if candidate == 1, o.transition_mode = 'retain'; else, o.transition_mode = 'cloud'; end
            if candidate == 3, o.radius_power = .25; else, o.radius_power = .5; end
        end
    end
    if strcmp(method, 'COMPLEX') && ~strcmp(id, 'C'), o.projection = true; end
end

function r = improvement_execute(protocol, id, method, seed, candidate)
    if nargin < 5, candidate = protocol.selected_candidate; end
    o = improved_options(protocol, id, method, candidate);
    index = find(strcmp({'A', 'B', 'C'}, id));
    starts = 1;
    if strcmp(method, 'BFGS'), starts = protocol.bfgs_starts(index); end
    if strcmp(method, 'COMPLEX'), starts = protocol.complex_starts(index); end
    if starts == 1
        r = execute_round3(id, method, seed, o, 'enhanced');
    else
        r = restarted_search(id, method, seed, o, starts);
    end
    r.phase = 'improvement';
    r.candidate = candidate;
    fprintf('IMPROVED %s %s seed=%d candidate=%d starts=%d target=%d error=%.5g eval=%d\n', ...
        id, method, seed, candidate, starts, r.metrics.success, r.metrics.objective_absolute_error, r.evaluations);
end

function r = restarted_search(id, method, seed, o, starts)
    % 重启次数预先固定；原目标只用于选最好可行输出，参考目标不参与控制。
    p = problem_definition(id);
    stream = RandStream('mt19937ar', 'Seed', seed);
    z0 = rand(stream, p.n, 1);
    restartStream = RandStream('mt19937ar', 'Seed', seed+300000);
    children = cell(starts, 1);
    best = [];
    trace = struct([]);
    evaluations = 0;
    gradients = 0;
    seconds = 0;
    projections = 0;
    projectionIterations = 0;
    timer = tic;
    for j = 1:starts
        point = z0;
        if j > 1, point = rand(restartStream, p.n, 1); end
        local = o;
        local.max_evaluations = floor(o.max_evaluations/starts);
        local.quiet = true;
        s = execute_round3(id, method, seed+1000*(j-1), local, 'restart_child', point);
        s.phase = 'improvement';
        children{j} = pack_trace_record(s);
        evaluations = evaluations+s.evaluations;
        gradients = gradients+s.gradient_evaluations;
        seconds = seconds+s.seconds;
        if isfield(s, 'projection_calls')
            projections = projections+s.projection_calls;
            projectionIterations = projectionIterations+s.projection_scalar_iterations;
        end
        if isempty(best) || prefer_raw(s.final_detail, best.final_detail, p), best = s; end
        d = best.final_detail;
        trace = [trace; struct('evaluations', evaluations, 'f', d.f, 'max_g', d.max_g, ...
            'max_h', d.max_h, 'max_bound', d.max_bound, 'z', best.z)]; %#ok<AGROW>
    end
    r = struct('method', ['restarted_', lower(method)], 'base_method', method, ...
        'problem', id, 'variant', 'enhanced', 'phase', 'improvement', ...
        'initialization_seed', seed, 'z0', z0, 'options', o, 'z', best.z, ...
        'final_detail', best.final_detail, 'metrics', best.metrics, 'status', 'fixed_restart_limit', ...
        'evaluations', evaluations, 'gradient_evaluations', gradients, ...
        'seconds', seconds, 'wall_seconds', toc(timer), 'restarts', {children}, ...
        'restart_count', starts, 'trace', trace, 'swarm_size', 0, ...
        'projection_calls', projections, 'projection_scalar_iterations', projectionIterations);
    r.verified = round3_check_run(r);
    assert(r.verified, 'Restarted solver cost/data verification failed.');
end

function output = improvement_entry(root, dataPath, mode)
    stored = load(dataPath, 'coursework_results');
    if strcmp(mode, 'improve_pilot')
        assert(~isfield(stored.coursework_results, 'improvement'), 'Improvement pilot already saved.');
        oldSection = stored.coursework_results.round3;
        old = oldSection.batches{oldSection.latest};
        assert(old.independent_review.all_passed);
        codeReview = review_sources(root);
        tests = coursework_main('selftest');
        % 修改后重跑旧三法9个组合，证明未开启新选项时保留原数值行为。
        legacyRegression = reproduce_round3(old);
        protocol = struct('version', 'improvement-lock-v1', 'baseline_protocol', old.protocol, ...
            'training_seeds', 2026102801:2026102805, 'holdout_seeds', 2026102811:2026102815, ...
            'formal_seeds', 2026102901:2026102930, 'selected_candidate', 1, ...
            'bfgs_starts', [1, 40, 1], 'complex_starts', [8, 128, 1], ...
            'candidate_names', {{'residual_retain', 'residual_cloud', 'residual_cloud_quarter'}}, ...
            'selection_rule', 'Training success count, feasible count, then smallest change from baseline', ...
            'performance_target', 20, 'model_and_acceptance_unchanged', true);
        development = cell(0, 1);
        for candidate = 1:3
            for seed = protocol.training_seeds
                development{end+1, 1} = improvement_execute(protocol, 'C', 'PSO', seed, candidate); %#ok<AGROW>
            end
        end
        rows = struct([]);
        for candidate = 1:3
            group = development(cellfun(@(r) r.candidate == candidate, development));
            rows(candidate).Candidate = protocol.candidate_names{candidate};
            rows(candidate).Successes = sum(cellfun(@(r) r.metrics.success, group));
            rows(candidate).Feasible = sum(cellfun(@(r) r.metrics.main_feasible, group));
            rows(candidate).MedianError = median(cellfun(@(r) r.metrics.objective_absolute_error, group));
        end
        comparison = struct2table(rows);
        [~, order] = sortrows([-comparison.Successes, -comparison.Feasible, (1:3)']);
        protocol.selected_candidate = order(1);
        combinations = {'A', 'COMPLEX'; 'B', 'BFGS'; 'B', 'COMPLEX'; 'C', 'BFGS'; 'C', 'PSO'};
        for k = 1:4
            for seed = protocol.training_seeds
                development{end+1, 1} = improvement_execute(protocol, combinations{k,1}, ...
                    combinations{k,2}, seed); %#ok<AGROW>
            end
        end
        holdout = cell(0, 1);
        for k = 1:size(combinations, 1)
            for seed = protocol.holdout_seeds
                holdout{end+1, 1} = improvement_execute(protocol, combinations{k,1}, ...
                    combinations{k,2}, seed); %#ok<AGROW>
            end
        end
        batch = struct('id', char(datetime('now', 'TimeZone', 'Asia/Shanghai', ...
            'Format', 'yyyyMMdd_HHmmss_SSS')), 'source_version', 'improvement-v1.0', ...
            'status', 'locked', 'protocol', protocol, 'tests', tests, 'code_review', codeReview, ...
            'source_snapshot', fileread(fullfile(root, 'coursework_main.m')), ...
            'baseline_batch_id', old.id, 'legacy_regression', legacyRegression, ...
            'development_runs', {development}, 'holdout_runs', {holdout}, ...
            'candidate_comparison', comparison, 'holdout_summary', round3_statistics(holdout), ...
            'experiments', {cell(0, 1)}, 'ablation_runs', {cell(0, 1)});
        save_improvement(root, dataPath, batch);
        disp(comparison);
        disp(batch.holdout_summary);
        assert(all(batch.holdout_summary.Successes >= 4), ...
            'coursework:ImprovementHoldout', 'Pilot retained; holdout needs further diagnosis before final testing.');
        output = batch;
        return;
    end
    assert(isfield(stored.coursework_results, 'improvement'), 'Run improve_pilot first.');
    section = stored.coursework_results.improvement;
    batch = section.batches{section.latest};
    if strcmp(mode, 'summary_improved')
        disp(batch.summary_validation);
        disp(batch.summary_comparison);
        disp(batch.checks);
        output = batch;
    elseif strcmp(mode, 'plot_improved')
        output = plot_improvement(batch, root);
    else
        output = run_improvement(root, dataPath, batch);
    end
end

function save_improvement(root, dataPath, batch)
    stored = load(dataPath, 'coursework_results');
    coursework_results = stored.coursework_results;
    if ~isfield(coursework_results, 'improvement')
        coursework_results.improvement = struct('batches', {{batch}}, 'latest', 1);
    else
        section = coursework_results.improvement;
        assert(strcmp(section.batches{section.latest}.id, batch.id));
        coursework_results.improvement.batches{section.latest} = batch;
    end
    pending = fullfile(root, '90_临时文件', 'coursework_results_pending.mat');
    info = whos('coursework_results');
    fileFormat = '-v7';
    if info.bytes > 1.5e9, fileFormat = '-v7.3'; end
    save(pending, 'coursework_results', fileFormat);
    [ok, message] = movefile(pending, dataPath, 'f');
    assert(ok, message);
end

function batch = run_improvement(root, dataPath, batch)
    if strcmp(batch.status, 'complete')
        disp(batch.summary_validation);
        return;
    end
    assert(all(batch.holdout_summary.Successes >= 4), 'Holdout gate has not passed.');
    expectedSource = batch.source_snapshot;
    if isfield(batch, 'resume_source_snapshot'), expectedSource = batch.resume_source_snapshot; end
    assert(strcmp(expectedSource, fileread(fullfile(root, 'coursework_main.m'))), ...
        'Frozen improvement source changed before testing.');
    protocol = batch.protocol;
    ids = {'A', 'B', 'C'};
    methods = {'BFGS', 'PSO', 'COMPLEX'};
    controls = [1, 3; 2, 1; 2, 3; 3, 1; 3, 2];
    jobs = zeros(0, 4);
    for seed = protocol.formal_seeds
        for k = 1:3
            for m = 1:3, jobs(end+1, :) = [k, m, seed, 1]; end %#ok<AGROW>
        end
        for k = 1:size(controls, 1), jobs(end+1, :) = [controls(k, :), seed, 0]; end %#ok<AGROW>
    end
    stream = RandStream('mt19937ar', 'Seed', 2026102888);
    jobs = jobs(randperm(stream, size(jobs, 1)), :);
    batch.status = 'running';
    for j = numel(batch.experiments)+1:size(jobs, 1)
        job = jobs(j, :);
        if job(4)
            r = improvement_execute(protocol, ids{job(1)}, methods{job(2)}, job(3));
        else
            o = round3_options(protocol.baseline_protocol, ids{job(1)}, methods{job(2)}, 1);
            r = execute_round3(ids{job(1)}, methods{job(2)}, job(3), o, 'paired_baseline');
            r.phase = 'improvement';
        end
        batch.experiments{j, 1} = r;
        if mod(j, 20) == 0 || j == size(jobs, 1)
            save_improvement(root, dataPath, batch);
            fprintf('IMPROVEMENT_CHECKPOINT=%d/420\n', j);
        end
    end
    % B题配对消融：区分投影与重启的影响，另20组，不反过来选择参数。
    for j = numel(batch.ablation_runs)+1:20
        seed = protocol.formal_seeds(ceil(j/2));
        if mod(j, 2)
            o = round3_options(protocol.baseline_protocol, 'B', 'COMPLEX', 1);
            r = restarted_search('B', 'COMPLEX', seed, o, 128);
            r.variant = 'restart128_no_projection';
        else
            o = improved_options(protocol, 'B', 'COMPLEX');
            r = execute_round3('B', 'COMPLEX', seed, o, 'projection_single');
        end
        r.phase = 'improvement';
        batch.ablation_runs{j, 1} = r;
        if mod(j, 10) == 0, save_improvement(root, dataPath, batch); end
    end
    enhanced = batch.experiments(cellfun(@(r) strcmp(r.variant, 'enhanced'), batch.experiments));
    baseline = batch.experiments(cellfun(@(r) strcmp(r.variant, 'paired_baseline'), batch.experiments));
    % 原始运行只存一份，两个视图用索引引用，避免重复保存整套子轨迹。
    batch.validation_indices = find(cellfun(@(r) strcmp(r.variant, 'enhanced'), batch.experiments));
    batch.control_indices = find(cellfun(@(r) strcmp(r.variant, 'paired_baseline'), batch.experiments));
    batch.table_validation = improvement_table(enhanced);
    batch.table_comparison = improvement_table(batch.experiments);
    batch.summary_validation = improvement_statistics(enhanced);
    batch.summary_comparison = improvement_statistics(batch.experiments);
    paired = enhanced(cellfun(@(r) strcmp(r.problem, 'B') && strcmp(r.base_method, 'COMPLEX') ...
        && ismember(r.initialization_seed, protocol.formal_seeds(1:10)), enhanced));
    batch.summary_ablation = improvement_statistics([paired; batch.ablation_runs]);
    rows = struct([]);
    for id = ids
        for method = methods
            prior = enhanced{find(cellfun(@(r) strcmp(r.problem, id{1}) ...
                && strcmp(r.base_method, method{1}) && r.initialization_seed == protocol.formal_seeds(1), enhanced), 1)};
            repeat = improvement_execute(protocol, id{1}, method{1}, protocol.formal_seeds(1));
            row = struct('Problem', id{1}, 'Method', method{1}, ...
                'Passed', isequaln(remove_times(prior), remove_times(repeat)));
            rows = [rows; row]; %#ok<AGROW>
        end
    end
    batch.reproduction_checks = struct2table(rows);
    checks = struct('validation_270', numel(enhanced) == 270, 'paired_controls_150', numel(baseline) == 150, ...
        'ablation_20', numel(batch.ablation_runs) == 20, ...
        'raw_and_budget_checks', all(cellfun(@round3_check_run, [batch.experiments; batch.ablation_runs])), ...
        'all_combinations_at_least_20_of_30', all(batch.summary_validation.Successes >= protocol.performance_target), ...
        'nine_reproductions', all(batch.reproduction_checks.Passed), ...
        'test_seeds_held_out', isempty(intersect(protocol.formal_seeds, ...
        [protocol.training_seeds, protocol.holdout_seeds])), 'paired_starts', true, 'common_C_preconditioning', true);
    for id = ids
        for seed = protocol.formal_seeds
            group = enhanced(cellfun(@(r) strcmp(r.problem, id{1}) && r.initialization_seed == seed, enhanced));
            checks.paired_starts = checks.paired_starts && numel(group) == 3 ...
                && isequal(group{1}.z0, group{2}.z0, group{3}.z0);
            if strcmp(id{1}, 'C')
                pair = group(cellfun(@(r) ~strcmp(r.base_method, 'COMPLEX'), group));
                checks.common_C_preconditioning = checks.common_C_preconditioning ...
                    && strcmp(pair{1}.options.coordinates, pair{2}.options.coordinates) ...
                    && isequal(pair{1}.options.r_schedule, pair{2}.options.r_schedule);
            end
        end
    end
    checks.all_passed = all(structfun(@(v) logical(v), checks));
    batch.checks = checks;
    batch.status = 'tested';
    save_improvement(root, dataPath, batch);
    disp(batch.summary_validation);
    assert(checks.all_passed, 'coursework:ImprovementGoal', 'Testing retained; review any unmet goal without hiding the cohort.');
    batch.figure_paths = plot_improvement(batch, root);
    batch.status = 'complete';
    batch.completed_at = char(datetime('now', 'TimeZone', 'Asia/Shanghai'));
    save_improvement(root, dataPath, batch);
end

function r = remove_times(r)
    % 多起点也递归排除计时字段；其余原始记录应逐字段复现。
    r = unpack_trace_record(r);
    if isfield(r, 'seconds'), r = rmfield(r, 'seconds'); end
    if isfield(r, 'wall_seconds'), r = rmfield(r, 'wall_seconds'); end
    if isfield(r, 'restarts')
        for j = 1:numel(r.restarts), r.restarts{j} = remove_times(r.restarts{j}); end
    end
end

function r = pack_trace_record(r)
    % 无损列式存储：每个字段按检查点拼成矩阵，保留形状、类型和NaN。
    if isfield(r, 'trace_storage') || isempty(r.trace), return; end
    trace = r.trace;
    names = fieldnames(trace);
    shapes = cell(numel(names), 1);
    columns = struct;
    for j = 1:numel(names)
        values = {trace.(names{j})};
        shapes{j} = size(values{1});
        kind = class(values{1});
        for k = 1:numel(values)
            assert((isnumeric(values{k}) || islogical(values{k})) ...
                && strcmp(class(values{k}), kind) && isequal(size(values{k}), shapes{j}));
            values{k} = values{k}(:);
        end
        columns.(names{j}) = cat(2, values{:});
    end
    r.trace = columns;
    r.trace_storage = 'columns-v1';
    r.trace_shapes = shapes;
    r.trace_size = size(trace);
end

function r = unpack_trace_record(r)
    % 兼容旧逐点结构体和新列式记录；还原后移除格式标记，逐字段值不变。
    if ~isfield(r, 'trace_storage'), return; end
    assert(strcmp(r.trace_storage, 'columns-v1'));
    names = fieldnames(r.trace);
    template = cell2struct(cell(numel(names), 1), names, 1);
    trace = repmat(template, r.trace_size);
    for j = 1:numel(names)
        values = r.trace.(names{j});
        for k = 1:numel(trace)
            trace(k).(names{j}) = reshape(values(:, k), r.trace_shapes{j});
        end
    end
    r.trace = trace;
    r = rmfield(r, {'trace_storage', 'trace_shapes', 'trace_size'});
end

function T = improvement_table(runs)
    T = round3_table(runs);
    T.CoordinateEvaluations = zeros(height(T), 1);
    T.ProjectionCalls = zeros(height(T), 1);
    T.ProjectionScalarIterations = zeros(height(T), 1);
    T.Starts = ones(height(T), 1);
    for j = 1:numel(runs)
        r = runs{j};
        if isfield(r, 'coordinate_evaluations'), T.CoordinateEvaluations(j) = r.coordinate_evaluations; end
        if isfield(r, 'projection_calls'), T.ProjectionCalls(j) = r.projection_calls; end
        if isfield(r, 'projection_scalar_iterations'), T.ProjectionScalarIterations(j) = r.projection_scalar_iterations; end
        if isfield(r, 'restart_count'), T.Starts(j) = r.restart_count; end
    end
end

function summary = improvement_statistics(runs)
    summary = round3_statistics(runs);
    T = improvement_table(runs);
    summary.MedianCoordinateEvaluations = zeros(height(summary), 1);
    summary.MedianProjectionCalls = zeros(height(summary), 1);
    summary.MedianProjectionIterations = zeros(height(summary), 1);
    summary.Starts = ones(height(summary), 1);
    for j = 1:height(summary)
        mask = strcmp(T.Problem, summary.Problem{j}) & strcmp(T.Method, summary.Method{j}) ...
            & strcmp(T.Variant, summary.Variant{j});
        summary.MedianCoordinateEvaluations(j) = median(T.CoordinateEvaluations(mask));
        summary.MedianProjectionCalls(j) = median(T.ProjectionCalls(mask));
        summary.MedianProjectionIterations(j) = median(T.ProjectionScalarIterations(mask));
        summary.Starts(j) = median(T.Starts(mask));
    end
end

function paths = plot_improvement(batch, root)
    colors = [0.15, .4, .75; .1, .6, .3];
    paths = cell(4, 1);
    pairs = {'A','COMPLEX'; 'B','BFGS'; 'B','COMPLEX'; 'C','BFGS'; 'C','PSO'};
    labels = {'A复合形', 'B外罚+BFGS', 'B复合形', 'G05外罚+BFGS', 'G05外罚+PSO'};
    targets = zeros(5, 2);
    costs = zeros(5, 2);
    for j = 1:5
        for k = 1:2
            variant = 'paired_baseline';
            if k == 2, variant = 'enhanced'; end
            S = batch.summary_comparison;
            row = strcmp(S.Problem, pairs{j,1}) & strcmp(S.Method, pairs{j,2}) & strcmp(S.Variant, variant);
            targets(j,k) = 100*S.Successes(row)/S.Runs(row);
            costs(j,k) = S.MedianEval(row);
        end
    end
    fig = round3_figure([1400, 530]);
    tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
    ax = nexttile;
    b = bar(ax, targets);
    for k = 1:2, b(k).FaceColor = colors(k,:); end
    ylim(ax, [0, 110]);
    set(ax, 'XTickLabel', labels, 'XTickLabelRotation', 20);
    ylabel(ax, '目标达标率（%）');
    title(ax, '同30个全新种子的配对比较');
    legend(ax, {'原方案', '改进方案'}, 'Location', 'southoutside');
    ax = nexttile;
    b = bar(ax, costs);
    for k = 1:2, b(k).FaceColor = colors(k,:); end
    set(ax, 'YScale', 'log', 'XTickLabel', labels, 'XTickLabelRotation', 20);
    ylabel(ax, '实际联合评价次数中位数');
    title(ax, '每题总预算不变；转换与重启调用计入');
    paths{1} = finish_round3_figure(fig, root, 'improved_01_paired.png');

    fig = round3_figure([1300, 550]);
    tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
    ax1 = nexttile;
    hold(ax1, 'on');
    ax2 = nexttile;
    hold(ax2, 'on');
    names = {'原坐标PSO', '残差坐标PSO', '残差坐标BFGS', '复合形+等式恢复'};
    methodNames = {'PSO', 'PSO', 'BFGS', 'COMPLEX'};
    variants = {'paired_baseline', 'enhanced', 'enhanced', 'enhanced'};
    colors = [.85,.25,.1; .1,.6,.3; .15,.4,.75; .5,.3,.65];
    points = logspace(0, log10(500000), 140);
    p = problem_definition('C');
    for k = 1:4
        group = batch.experiments(cellfun(@(r) strcmp(r.problem,'C') ...
            && strcmp(r.base_method,methodNames{k}) && strcmp(r.variant,variants{k}), batch.experiments));
        errors = NaN(30, numel(points));
        violation = errors;
        for j = 1:30
            t = group{j}.trace;
            for q = 1:numel(points)
                ix = find([t.evaluations] <= points(q), 1, 'last');
                if isempty(ix), continue; end
                errors(j,q) = abs(t(ix).f-p.reference_f);
                violation(j,q) = raw_violation(p,t(ix).max_g,t(ix).max_h,t(ix).max_bound);
            end
        end
        % 用完整30个样本形成中位数；未完成所有初始评价的预算位置保留缺失。
        medError = median(errors,1);
        medViolation = median(violation,1);
        medError(medError < 1e-12) = 1e-12;
        medViolation(medViolation < 1e-8) = 1e-8;
        assert(all(isnan(medError(any(isnan(errors),1)))));
        loglog(ax1,points,medError,'LineWidth',1.6,'Color',colors(k,:),'DisplayName',names{k});
        loglog(ax2,points,medViolation,'LineWidth',1.6,'Color',colors(k,:),'DisplayName',names{k});
    end
    set([ax1,ax2],'XScale','log','YScale','log','XLim',[1,500000]);
    yline(ax1,.01,'--','目标阈值','HandleVisibility','off');
    yline(ax2,1,'--','可行阈值','HandleVisibility','off');
    title(ax1,'G05：原目标误差中位数（含不可行检查点）');
    title(ax2,'G05：归一化约束违反量中位数');
    xlabel(ax1,'累计联合评价次数');
    xlabel(ax2,'累计联合评价次数');
    legend(ax1,'Location','southoutside','NumColumns',2);
    paths{2} = finish_round3_figure(fig,root,'improved_02_G05_convergence.png');

    fig = round3_figure([1250, 520]);
    tiledlayout(fig,1,2,'TileSpacing','compact');
    S = batch.summary_ablation;
    labels = S.Variant;
    for j = 1:numel(labels)
        switch labels{j}
            case 'enhanced', labels{j} = '投影+128起点';
            case 'projection_single', labels{j} = '投影+单起点';
            case 'restart128_no_projection', labels{j} = '无投影+128起点';
        end
    end
    ax = nexttile;
    bar(ax,100*S.Successes./S.Runs);
    ylim(ax,[0,110]);
    set(ax,'XTick',1:height(S),'XTickLabel',labels,'XTickLabelRotation',15);
    ylabel(ax,'B题达标率（%）');
    title(ax,'投影与重启消融：同10个种子');
    ax = nexttile;
    bar(ax,S.MedianEval);
    set(ax,'YScale','log','XTick',1:height(S),'XTickLabel',labels,'XTickLabelRotation',15);
    ylabel(ax,'联合评价次数中位数');
    title(ax,'总上限30万；投影标量迭代另列且计时');
    paths{3} = finish_round3_figure(fig,root,'improved_03_B_ablation.png');

    fig = round3_figure([1320, 460]);
    tiledlayout(fig,1,3,'TileSpacing','compact');
    methods = {'BFGS','PSO','COMPLEX'};
    ids = {'A','B','C'};
    T = batch.table_validation;
    for k = 1:3
        ax = nexttile;
        hold(ax,'on');
        for m = 1:3
            group = sortrows(T(strcmp(T.Problem,ids{k}) & strcmp(T.Method,methods{m}),:),'Seed');
            scatter(ax,m+linspace(-.16,.16,30)',max(group.AbsError,1e-12),22,'filled');
        end
        p = problem_definition(ids{k});
        yline(ax,p.objective_tolerance,'--','目标阈值');
        set(ax,'YScale','log','XTick',1:3,'XTickLabel',{'BFGS','PSO','复合形'});
        xlim(ax,[.5,3.5]);
        limits = ylim(ax);
        ylim(ax,[limits(1)/2,limits(2)*1.3]);
        title(ax,[ids{k},'：30次误差（零值显示为10^{-12}）']);
        ylabel(ax,'原目标绝对误差');
    end
    paths{4} = finish_round3_figure(fig,root,'improved_04_distribution.png');
end

function tests = improvement_selftests
    tests = struct([]);
    p = problem_definition('C');
    o = pso_options(12);
    o.coordinates = 'G05_residual';
    o.boundary_mode = 'penalty';
    stream = RandStream('mt19937ar', 'Seed', 2026102800);
    native = rand(stream, 4, 20);
    [search, calls] = to_search_coordinates(p, native, o);
    back = from_search_coordinates(p, search, o);
    difference = max(abs(native-back), [], 'all');
    tests = check(tests, 'Improved_C_coordinate_roundtrip', difference < 2e-12 && calls == 20, difference);
    nativeOutside = -2+5*rand(stream, 4, 20);
    outside = from_search_coordinates(p, to_search_coordinates(p, nativeOutside, o), o);
    difference = max(abs(nativeOutside-outside), [], 'all');
    tests = check(tests, 'Improved_C_extension_roundtrip', difference < 2e-11, difference);
    points = [.5, -.8, 1.7; .01, -.2, .4; -.02, .3, -.7; .03, 3, -2];
    maximum = 0;
    sameValue = 0;
    for j = 1:size(points, 2)
        w = points(:, j);
        [value, gradient] = search_penalty(p, w, 3, o, true);
        [onlyValue, none] = search_penalty(p, w, 3, o, false);
        sameValue = max(sameValue, abs(value-onlyValue));
        assert(isempty(none));
        numeric = zeros(4, 1);
        for k = 1:4
            step = zeros(4, 1);
            step(k) = 1e-6;
            numeric(k) = (search_penalty(p, w+step, 3, o, false) ...
                - search_penalty(p, w-step, 3, o, false))/2e-6;
        end
        maximum = max(maximum, norm(numeric-gradient, inf)/max(1, norm(gradient, inf)));
    end
    tests = check(tests, 'Improved_C_chain_rule', maximum < 2e-5, maximum);
    tests = check(tests, 'Improved_C_same_value_only_penalty', sameValue == 0, sameValue);
    w = [.5; .01; -.02; .03];
    z = from_search_coordinates(p, w, o);
    d = raw_model_detail(p, z);
    tests = check(tests, 'Improved_C_keeps_four_variables_three_equalities', ...
        numel(w) == 4 && norm(d.h/1000-w(2:4), inf) < 2e-12 ...
        && d.max_h > 1, d.max_h);

    % 投影用独立密网边界距离核对；不以原优化目标评价投影本身。
    a = problem_definition('A');
    worstDistance = 0;
    feasible = true;
    grid = linspace(0, 1, 4001);
    for j = 1:24
        x = -1+3*rand(stream, 2, 1);
        source = (x-a.lb)./(a.ub-a.lb);
        projected = project_parabolic(a, source);
        raw = a.lb+(a.ub-a.lb).*projected;
        d = raw_model_detail(a, projected);
        feasible = feasible && d.max_g <= 1e-12 && d.max_bound == 0;
        if max(0, x(1))^2+max(0, x(2)) > 1
            gridDistance = min((grid-x(1)).^2+(1-grid.^2-x(2)).^2);
            worstDistance = max(worstDistance, sum((raw-x).^2)-gridDistance);
        end
    end
    tests = check(tests, 'Improved_projection_feasible_and_nearest', ...
        feasible && worstDistance < 1e-9, worstDistance);
    source = [.9; .2];
    one = project_parabolic(a, source);
    a.reference_x = [-999; 999];
    a.reference_f = -1e20;
    tests = check(tests, 'Improved_projection_no_reference', ...
        isequal(one, project_parabolic(a, source)) ...
        && norm(one-project_parabolic(a, one), inf) < 1e-12, 0);

    o.max_outer = 3;
    o.r_schedule = [1, 10, 100];
    o.max_evaluations = 6000;
    r = exterior_pso(p, .5*ones(4, 1), o, 229);
    r.problem = 'C';
    r.options = o;
    r.swarm_size = 12;
    tests = check(tests, 'Improved_PSO_mapping_budget_memory', ...
        check_pso_history(r) && r.evaluations <= 6000 ...
        && r.evaluations == sum([r.stages.evaluations])+r.coordinate_evaluations ...
        && r.trace(end).evaluations == r.evaluations && r.gradient_evaluations == 0, r.evaluations);
    b = default_options;
    b.coordinates = 'G05_residual';
    b.max_evaluations = 2000;
    r = exterior_bfgs(p, .5*ones(4, 1), b);
    audit = recheck_wolfe(r.trace, b);
    tests = check(tests, 'Improved_BFGS_mapping_budget_Wolfe', ...
        r.evaluations <= 2000 && r.evaluations == r.gradient_evaluations+r.coordinate_evaluations ...
        && audit.violations == 0 && audit.steps_checked == r.wolfe_steps, r.evaluations);
    encoded = pack_trace_record(r);
    tests = check(tests, 'Improved_lossless_column_trace_roundtrip', ...
        isequaln(r, unpack_trace_record(encoded)) && isequaln(r, unpack_trace_record(r)), numel(r.trace));
    fprintf('IMPROVEMENT_SELFTESTS=%d PASS\n', numel(tests));
end

function yes = residual_coordinates(o)
    yes = isfield(o, 'coordinates') && strcmp(o.coordinates, 'G05_residual');
end

function [w, cost] = to_search_coordinates(p, z, o)
    % G05仍为四维：w=[归一化x3; h1/1000; h2/1000; h3/1000]（原边界内）。
    % 这是换坐标，不把等式残差固定为0；外罚函数仍处理全部原约束。
    w = z;
    cost = 0;
    if ~residual_coordinates(o), return; end
    assert(strcmp(p.id, 'C'));
    for j = 1:size(z, 2)
        x = p.lb + (p.ub-p.lb).*z(:, j);
        [~, ~, h] = model_eval(p, x, false);
        cost = cost + 1; % 正变换实际评价了模型，明确计入联合调用预算。
        factor = cosine_extension(x(3));
        theta = x(4)-x(3)/2-.25;
        extendedSine = sin(theta);
        if abs(theta) > 1.2
            extendedSine = sign(theta)*(sin(1.2)+cos(1.2)*(abs(theta)-1.2));
        end
        w(:, j) = [z(3, j); h(1:2)/1000; 1.2948+2*factor*extendedSine];
    end
end

function [z, J] = from_search_coordinates(p, w, o)
    % 全实数域上的可逆C1延拓：原边界内与原等式残差坐标精确对应。
    % sin在|theta|<=1.2保持原式，外侧接正斜率直线；避免asin定义域错误。
    z = w;
    J = [];
    if ~residual_coordinates(o)
        if nargout > 1, J = eye(p.n); end
        return;
    end
    assert(strcmp(p.id, 'C'));
    for j = 1:size(w, 2)
        a = p.lb(3)+(p.ub(3)-p.lb(3))*w(1, j);
        [factor, derivative] = cosine_extension(a);
        y = (w(4, j)-1.2948)/(2*factor);
        if abs(y) <= sin(1.2)
            theta = asin(y);
            inverseSlope = 1/sqrt(1-y^2);
        else
            theta = sign(y)*(1.2+(abs(y)-sin(1.2))/cos(1.2));
            inverseSlope = 1/cos(1.2);
        end
        b = theta+a/2+.25;
        x = [1000*(sin(-a-.25)+sin(-b-.25)+.8948-w(2, j)); ...
            1000*(sin(a-.25)+sin(a-b-.25)+.8948-w(3, j)); a; b];
        z(:, j) = (x-p.lb)./(p.ub-p.lb);
        if nargout > 1
            assert(size(w, 2) == 1, 'Jacobian requested for one point at a time.');
            da = p.ub(3)-p.lb(3);
            db1 = da*(.5-inverseSlope*y*derivative/factor);
            db4 = inverseSlope/(2*factor);
            x1a = -1000*cos(-a-.25);
            x1b = -1000*cos(-b-.25);
            x2a = 1000*(cos(a-.25)+cos(a-b-.25));
            x2b = -1000*cos(a-b-.25);
            Jx = [x1a*da+x1b*db1, -1000, 0, x1b*db4; ...
                x2a*da+x2b*db1, 0, -1000, x2b*db4; ...
                da, 0, 0, 0; db1, 0, 0, db4];
            J = Jx./(p.ub-p.lb);
        end
    end
end

function [c, d] = cosine_extension(a)
    % 原x3边界内为cos(a/2)；外侧二次延拓匹配一阶导数，且始终大于0.95。
    c = cos(a/2);
    d = -.5*sin(a/2);
    if abs(a) > .55
        delta = abs(a)-.55;
        slope = -.5*sin(.275);
        c = cos(.275)+slope*delta+.5*delta^2;
        d = sign(a)*(slope+delta);
    end
end

function [value, gradient, detail] = search_penalty(p, w, r, o, withDerivatives)
    if ~residual_coordinates(o)
        [value, gradient, detail] = penalty_eval(p, w, r, withDerivatives);
    elseif withDerivatives
        [z, J] = from_search_coordinates(p, w, o);
        [value, nativeGradient, detail] = penalty_eval(p, z, r, true);
        gradient = J'*nativeGradient;
    else
        z = from_search_coordinates(p, w, o);
        [value, gradient, detail] = penalty_eval(p, z, r, false);
    end
end

function [z, iterations] = project_parabolic(p, z)
    % A/B每对变量的可行域为u>=0、v>=0、u^2+v<=1；投影不使用原目标。
    % 外部点的边界投影满足2*u^3+(2*b-1)*u-a=0，在[0,1]有唯一相关根。
    x = p.lb+(p.ub-p.lb).*z;
    iterations = 0;
    for j = 1:2:p.n
        a = x(j);
        b = x(j+1);
        u = max(0, a);
        v = max(0, b);
        if u^2+v > 1
            if a <= 0
                u = 0;
                v = 1;
            elseif b <= 0 || 1+2*b-a <= 0
                u = 1;
                v = 0;
            else
                lo = 0;
                hi = 1;
                for k = 1:45
                    mid = (lo+hi)/2;
                    if 2*mid^3+(2*b-1)*mid-a > 0, hi = mid; else, lo = mid; end
                    iterations = iterations+1;
                end
                u = (lo+hi)/2;
                v = 1-u^2;
            end
        end
        x(j:j+1) = [u; v];
    end
    z = (x-p.lb)./(p.ub-p.lb);
end

function r = penalty_parameter(o, k)
    % 第三轮显式给定11层序列，保证敏感性分析的首尾值、层数完全一致。
    if isfield(o, 'r_schedule')
        r = o.r_schedule(k);
    else
        r = min(o.r0 * o.r_factor^(k - 1), o.r_max);
    end
end

function o = default_options
    % BFGS与共同外罚法参数。r每层乘10；停止阈值不使用参考最优值。
    o = struct('r0', 1, 'r_factor', 10, 'r_max', 1e10, 'max_outer', 11, ...
        'max_evaluations', 1e5, 'max_iterations', 1000, 'gradient_tolerance', 1e-7, ...
        'step_tolerance', 1e-13, 'function_tolerance', 1e-14, ...
        'outer_step_tolerance', 1e-5, 'outer_kkt_tolerance', 1e-5, ...
        'c1', 1e-4, 'c2', .9, 'initial_alpha', 1, 'max_alpha', 256, ...
        'max_bracket', 20, 'max_zoom', 60);
end

function run = exterior_bfgs(p, z0, o)
    % 课件第4章外点法：固定r求子问题，增大r，以上层结果热启动。
    % p为模型，z0为归一化初始点，o为参数；run保存完整轨迹及退出原因。
    validateattributes(z0, {'double'}, {'column', 'numel', p.n, 'real', 'finite'});
    assert(~residual_coordinates(o) || o.max_evaluations >= 2, 'Residual coordinates need two initial calls.');
    clock = tic;
    [z, conversionCost] = to_search_coordinates(p, z0, o);
    total = conversionCost;
    gradients = 0;
    trace = struct([]);
    stages = struct([]);
    wolfeSteps = 0;
    violations = 0;
    lineFailures = 0;
    status = 'penalty_limit';
    previous = [];

    for k = 1:o.max_outer
        r = penalty_parameter(o, k);
        innerOptions = o;
        innerOptions.max_evaluations = o.max_evaluations-total;

        if innerOptions.max_evaluations<1
            status = 'evaluation_budget';
            break;
        end
        inner = bfgs_minimize(@(w) search_penalty(p, w, r, o, true), z, innerOptions);
        before = total;
        total = total+inner.evaluations;
        gradients = gradients+inner.gradient_evaluations;
        wolfeSteps = wolfeSteps+inner.wolfe_steps;
        violations = violations+inner.wolfe_violations;
        lineFailures = lineFailures+inner.line_failures;

        for j = 1:numel(inner.trace)
            h = inner.trace(j);
            d = h.detail;
            entry = struct('stage', k, 'r', r, 'iteration', h.iteration, ...
                'evaluations', before+h.evaluations, 'phi', h.phi, 'f', d.f, ...
                'max_g', d.max_g, 'max_h', d.max_h, 'max_bound', d.max_bound, ...
                'gradient_norm', h.gradient_norm, 'alpha', h.alpha, ...
                'armijo_slack', h.armijo_slack, 'curvature_slack', h.curvature_slack, ...
                'z', from_search_coordinates(p, h.z, o), 'x', d.x, 'gradient', h.gradient);
            if residual_coordinates(o), entry.search_z = h.z; end
            trace = [trace; entry]; %#ok<AGROW>
        end
        z = inner.z;
        d = inner.detail;
        kkt = kkt_diagnostic(p, d);

        if isempty(previous)
            outerStep = Inf;
        else
            outerStep = norm(z-previous, inf);
        end
        stage = struct('r', r, 'status', inner.status, 'evaluations', inner.evaluations, ...
            'iterations', inner.iterations, 'gradient_norm', norm(inner.gradient, inf), ...
            'outer_step', outerStep, 'kkt', kkt, 'direction_resets', inner.direction_resets, ...
            'updates_skipped', inner.updates_skipped, 'last_line_status', inner.last_line_status);
        stages = [stages; stage]; %#ok<AGROW>
        % 停止检查仅用原始可行性和近似一阶条件，不读取最优值或参考向量。
        feasible = d.max_g <= 1e-6 && d.max_h <= 1e-6 && d.max_bound <= 1e-8;
        stationary = kkt.stationarity_relative <= o.outer_kkt_tolerance ...
            && kkt.dual_violation <= 1e-5 && kkt.complementarity <= 1e-5;

        if feasible && stationary && outerStep <= o.outer_step_tolerance
            status = 'feasible_kkt';
            break;
        end
        if strcmp(inner.status, 'evaluation_budget') || total >= o.max_evaluations
            status = 'evaluation_budget';
            break;
        end
        if strcmp(inner.status, 'nonfinite_initial')
            status = 'nonfinite_initial';
            break;
        end
        previous = z;

        if r >= o.r_max
            break;
        end
    end
    assert(exist('d', 'var') == 1, 'No valid initial evaluation.');
    run = struct('method', 'exterior_penalty_bfgs', 'z', from_search_coordinates(p, z, o), 'final_detail', d, ...
        'status', status, 'stages', stages, 'trace', trace, 'kkt', kkt, ...
        'evaluations', total, 'gradient_evaluations', gradients, ...
        'wolfe_steps', wolfeSteps, 'wolfe_violations', violations, ...
        'line_failures', lineFailures, 'seconds', toc(clock));
    if residual_coordinates(o)
        run.search_z = z;
        run.coordinate_evaluations = conversionCost;
    end
end

function result = bfgs_minimize(fun, x0, o)
    % 课件第3章BFGS：H近似逆Hessian，方向为-H*g。
    % fun返回[函数值,梯度,原问题信息]；每次调用均计入硬预算。
    % 接受步必须满足强Wolfe条件；曲率不足则跳过更新并记录。
    x = x0(:);
    n = numel(x);
    H = eye(n);
    neval = 0;
    ngeval = 0;
    resets = 0;
    skipped = 0;
    failures = 0;
    wolfeSteps = 0;
    wolfeViolations = 0;
    lastLine = 'not_called';
    trace = struct([]);
    iterations = 0;
    [f, g, detail] = counted(x);
    trace = trace_row(0, NaN, NaN, NaN);
    status = 'iteration_limit';

    if ~isfinite(f) || any(~isfinite(g))
        status = 'nonfinite_initial';
        result = package;
        return;
    end
    for k = 1:o.max_iterations
        if norm(g, inf) <= o.gradient_tolerance*max(1, abs(f))
            status = 'gradient_tolerance';
            break;
        end
        if neval >= o.max_evaluations
            status = 'evaluation_budget';
            break;
        end
        direction = -H*g;

        if any(~isfinite(direction)) || g'*direction >= -1e-14*norm(g)*norm(direction)
            H = eye(n);
            direction = -g;
            resets = resets+1;
        end
        try
            ls = strong_wolfe(@counted, x, f, g, direction, o);

            if ~ls.success && norm(direction+g)>1e-12*max(1, norm(g))
                % 当前曲率模型可能失效：允许重置为负梯度重试一次，成本照计。
                H = eye(n);
                direction = -g;
                resets = resets+1;
                failures = failures+1;
                ls = strong_wolfe(@counted, x, f, g, direction, o);
            end
        catch err
            if strcmp(err.identifier, 'coursework:Budget')
                status = 'evaluation_budget';
                lastLine = 'evaluation_budget';
                break;
            end
            rethrow(err);
        end
        lastLine = ls.status;

        if ~ls.success
            failures = failures+1;
            status = 'line_search_failed';
            break;
        end
        s = ls.x-x;
        y = ls.g-g;
        oldF = f;
        x = ls.x;
        f = ls.f;
        g = ls.g;
        detail = ls.detail;
        iterations = k;
        wolfeSteps = wolfeSteps+1;

        if ls.armijo_slack<0 || ls.curvature_slack<0
            wolfeViolations = wolfeViolations+1;
        end
        ys = y'*s;

        if ys>sqrt(eps)*norm(s)*norm(y) && ys>0
            if k == 1
                H = (ys/(y'*y))*eye(n);
            end
            rho = 1/ys;
            V = eye(n)-rho*s*y';
            H = V*H*V'+rho*(s*s');
            H = (H+H')/2;
        else
            skipped = skipped+1;
        end
        trace(end+1) = trace_row(k, ls.alpha, ls.armijo_slack, ls.curvature_slack); %#ok<AGROW>
        if norm(s, inf) <= o.step_tolerance*(1+norm(x, inf)) ...
            && abs(f-oldF) <= o.function_tolerance*(1+abs(f))
            if norm(g, inf) <= o.gradient_tolerance*max(1, abs(f))
                status = 'gradient_tolerance';
            else
                status = 'step_stagnation';
            end
            break;
        end
    end
    if trace(end).evaluations<neval
        % 末次失败试探仍消耗计算：补记成本检查点，不伪造一次接受迭代。
        trace(end+1) = trace_row(-1, NaN, NaN, NaN);
    end
    result = package;

    function [value, gradient, details] = counted(point)
        if neval >= o.max_evaluations
            error('coursework:Budget', 'Evaluation budget exhausted.');
        end
        neval = neval+1;
        ngeval = ngeval+1;
        [value, gradient, details] = fun(point);
        gradient = gradient(:);
        assert(isscalar(value) && isreal(value) && numel(gradient) == n ...
            && isreal(gradient), 'Invalid objective/gradient dimensions.');
    end
    function row = trace_row(iter, alpha, armijo, curvature)
        row = struct('iteration', iter, 'evaluations', neval, 'z', x, 'phi', f, ...
            'gradient_norm', norm(g, inf), 'gradient', g, 'alpha', alpha, ...
            'armijo_slack', armijo, 'curvature_slack', curvature, 'detail', detail);
    end
    function r = package
        r = struct('z', x, 'value', f, 'gradient', g, 'detail', detail, 'status', status, ...
            'evaluations', neval, 'gradient_evaluations', ngeval, ...
            'iterations', iterations, 'trace', trace, 'wolfe_steps', wolfeSteps, ...
            'wolfe_violations', wolfeViolations, 'line_failures', failures, ...
            'direction_resets', resets, 'updates_skipped', skipped, 'last_line_status', lastLine);
    end
end

function ls = strong_wolfe(fun, x, f0, g0, d, o)
    % 课件第1章第69页：充分下降条件 + 强曲率条件。
    % 先扩张括区间，再二分缩小区间；ls.success明确区分成功与失败。
    slope0 = g0'*d;
    ls = struct('success', false, 'status', 'bracket_limit', 'alpha', 0, ...
        'x', x, 'f', f0, 'g', g0, 'detail', struct, 'armijo_slack', NaN, 'curvature_slack', NaN);

    if ~isfinite(slope0) || slope0 >= 0
        ls.status = 'not_descent';
        return;
    end
    alpha = o.initial_alpha;
    oldAlpha = 0;
    oldF = f0;

    for j = 1:o.max_bracket
        [f, g, detail] = fun(x+alpha*d);

        if ~isfinite(f) || any(~isfinite(g)) ...
            || f>f0+o.c1*alpha*slope0 || (j>1 && f >= oldF)
            ls = zoom(oldAlpha, alpha, oldF);
            return;
        end
        slope = g'*d;

        if abs(slope) <= -o.c2*slope0
            ls = accept(alpha, f, g, detail);
            return;
        end
        if slope >= 0
            ls = zoom(alpha, oldAlpha, f);
            return;
        end
        if alpha >= o.max_alpha
            ls.status = 'maximum_alpha';
            return;
        end
        oldAlpha = alpha;
        oldF = f;
        alpha = min(2*alpha, o.max_alpha);
    end

    function found = zoom(lo, hi, flo)
        found = ls;
        found.status = 'zoom_limit';

        for q = 1:o.max_zoom
            a = (lo+hi)/2;

            if a == lo || a == hi || abs(hi-lo)<1e-15*max(1, abs(a))
                found.status = 'zoom_interval_stalled';
                return;
            end
            [fa, ga, da] = fun(x+a*d);

            if ~isfinite(fa) || any(~isfinite(ga)) ...
                || fa>f0+o.c1*a*slope0 || fa >= flo
                hi = a;
            else
                slope = ga'*d;

                if abs(slope) <= -o.c2*slope0
                    found = accept(a, fa, ga, da);
                    return;
                end
                if slope*(hi-lo) >= 0
                    hi = lo;
                end
                lo = a;
                flo = fa;
            end
        end
    end
    function found = accept(a, fa, ga, da)
        found = struct('success', true, 'status', 'strong_wolfe', 'alpha', a, ...
            'x', x+a*d, 'f', fa, 'g', ga, 'detail', da, ...
            'armijo_slack', f0+o.c1*a*slope0-fa, ...
            'curvature_slack', -o.c2*slope0-abs(ga'*d));
    end
end

%% 第二轮：外罚函数 + PSO（粒子群优化）
function o = pso_options(swarmSize)
    % 采用全局最优拓扑的惯性权重PSO；这里列出全部可影响结果的参数。
    % 参数比较只改变粒子数40/80，其余参数固定，避免无依据的大范围调参。
    o = default_options;
    o.swarm_size = swarmSize;
    o.inertia_start = 0.9;
    o.inertia_end = 0.4;
    o.cognitive = 1.7;
    % 个体学习系数：追随自身历史最优。
    o.social = 1.7;
    % 群体学习系数：追随全体历史最优。
    o.velocity_limit = 0.2;
    % 归一化坐标中，每维最大移动速度。
    o.fitness_tolerance = 1e-12;
    o.swarm_tolerance = 1e-9;
    o.stall_generations = 60;
    o.trace_stride = 10;
    % 原始最优值每代保留，详细轨迹每10代保留。
    o.global_refresh_fraction = 0.2;
    o.transition_radius = 0.2;
    o.transition_radius_floor = 1e-7;
    o.max_generations = 1000;
    o.boundary_mode = 'clip'; % 旧阶段保持原行为；第三轮明确改为penalty。
    o.radius_power = 0.5;
    o.transition_mode = 'cloud';
    % 外层按每层预算重新计算，不跨层透支。
end

function run = exterior_pso(p, z0, o, seed)
    % 同一外罚框架的无导数实现。seed控制局部随机流，不改MATLAB全局随机流。
    % 外层只检查原始可行性和稳定性；已知最优值仅在求解结束后评价质量。
    validateattributes(z0, {'double'}, ...
        {'column', 'numel', p.n, 'real', 'finite', '>=', 0, '<=', 1});
    % 已保存的第二轮参数可能没有第三轮新增字段，补原默认值以兼容旧入口。
    if ~isfield(o, 'boundary_mode'), o.boundary_mode = 'clip'; end
    if ~isfield(o, 'radius_power'), o.radius_power = .5; end
    if ~isfield(o, 'transition_mode'), o.transition_mode = 'cloud'; end
    stream = RandStream('mt19937ar', 'Seed', seed);
    state = [];
    timer = tic;
    assert(~residual_coordinates(o) || o.max_evaluations >= 2*o.swarm_size, ...
        'Residual-coordinate PSO needs mapping and first-population evaluation budget.');
    [searchStart, conversionTotal] = to_search_coordinates(p, z0, o);
    total = conversionTotal;
    trace = struct([]);
    stages = struct([]);
    previous = [];
    status = 'penalty_limit';
    stageBudget = max(2 * o.swarm_size, floor(o.max_evaluations / o.max_outer));

    for k = 1:o.max_outer
        r = penalty_parameter(o, k);
        remaining = o.max_evaluations - total;
        minimum = o.swarm_size * (1 + ~isempty(state));
        conversionThis = 0;
        if residual_coordinates(o)
            if isempty(state)
                minimum = minimum + o.swarm_size - 1;
            else
                minimum = minimum + ceil(o.global_refresh_fraction * o.swarm_size);
            end
        end

        if remaining < minimum
            status = 'insufficient_stage_budget';
            break;
        end

        if ~isempty(state)
            % 高罚系数改变子问题：保留历史点，同时恢复搜索多样性。
            % 第三轮允许保留上层群体；旧阶段仍按原半径重新生成邻域云。
            if k > 1, previousR = penalty_parameter(o, k - 1); else, previousR = o.r0; end
            radius = max(o.transition_radius_floor, ...
                o.transition_radius / previousR^o.radius_power);
            if strcmp(o.transition_mode, 'cloud')
                state.positions = z + radius * randn(stream, p.n, o.swarm_size);
            end
            if strcmp(o.boundary_mode, 'clip')
                state.positions = min(1, max(0, state.positions));
            end
            globalCount = ceil(o.global_refresh_fraction * o.swarm_size);
            refresh = rand(stream, p.n, globalCount);
            [refresh, conversionThis] = to_search_coordinates(p, refresh, o);
            state.positions(:, 2:globalCount + 1) = refresh;
            state.positions(:, 1) = z;
            if strcmp(o.transition_mode, 'cloud')
                state.velocities = radius * (2 * rand(stream, p.n, o.swarm_size) - 1);
            end
        end

        innerOptions = o;
        if isempty(state) && residual_coordinates(o)
            native = rand(stream, p.n, o.swarm_size);
            [others, conversionThis] = to_search_coordinates(p, native(:, 2:end), o);
            innerOptions.initial_search_positions = [searchStart, others];
        end
        total = total + conversionThis;
        conversionTotal = conversionTotal + conversionThis;
        stageConversion = conversionThis;
        if k == 1 && residual_coordinates(o), stageConversion = stageConversion + 1; end
        innerOptions.max_evaluations = min(stageBudget-stageConversion, o.max_evaluations-total);
        initialCost = o.swarm_size * (1 + ~isempty(state));
        innerOptions.max_generations = max(1, ...
            ceil((innerOptions.max_evaluations - initialCost) / o.swarm_size));
        inner = pso_minimize(@(w) search_penalty(p, w, r, o, false), ...
            searchStart, innerOptions, stream, state);

        if k == 1
            initialSearchSwarm = inner.initial_positions;
            initialSwarm = from_search_coordinates(p, inner.initial_positions, o);
        end

        before = total;
        total = total + inner.evaluations;
        state = inner.state;
        z = inner.z;
        d = inner.detail;

        for j = 1:numel(inner.trace)
            h = inner.trace(j);
            entry = struct('stage', k, 'r', r, 'iteration', h.iteration, ...
                'evaluations', before + h.evaluations, 'phi', h.phi, ...
                'f', h.detail.f, 'max_g', h.detail.max_g, ...
                'max_h', h.detail.max_h, 'max_bound', h.detail.max_bound, ...
                'z', from_search_coordinates(p, h.z, o), 'x', h.detail.x);
            if residual_coordinates(o), entry.search_z = h.z; end
            trace = [trace; entry]; %#ok<AGROW>
        end
        if isempty(previous)
            outerStep = Inf;
        else
            outerStep = norm(z - previous, inf);
        end
        stage = struct('r', r, 'status', inner.status, ...
            'evaluations', inner.evaluations, 'generations', inner.generations, ...
            'outer_step', outerStep, 'memory_audit', inner.memory_audit, ...
            'history', inner.history, 'boundary_repairs', inner.boundary_repairs, ...
            'nonfinite_evaluations', inner.nonfinite_evaluations, ...
            'pbest', state.pbest, 'pbest_values', state.values);
        if residual_coordinates(o), stage.coordinate_evaluations = stageConversion; end
        stages = [stages; stage]; %#ok<AGROW>
        feasible = d.max_g <= 1e-6 && d.max_h <= 1e-6 && d.max_bound <= 1e-8;

        if feasible && outerStep <= o.outer_step_tolerance ...
            && strcmp(inner.status, 'swarm_stagnation')
            status = 'feasible_stable';
            break;
        end
        if total >= o.max_evaluations
            status = 'evaluation_budget';
            break;
        end
        if strcmp(inner.status, 'nonfinite_initial')
            status = 'nonfinite_initial';
            break;
        end
        previous = z;

        if r >= o.r_max
            break;
        end
    end

    run = struct('method', 'exterior_penalty_pso', 'z', from_search_coordinates(p, z, o), ...
        'final_detail', d, 'status', status, 'stages', stages, 'trace', trace, ...
        'evaluations', total, 'gradient_evaluations', 0, 'seed', seed, ...
        'seconds', toc(timer), 'final_state', state, 'initial_swarm', initialSwarm);
    if residual_coordinates(o)
        run.search_z = z;
        run.coordinate_evaluations = conversionTotal;
        run.initial_search_swarm = initialSearchSwarm;
    end
end

function result = pso_minimize(fun, z0, o, stream, state)
    % 一个固定罚系数下的PSO子问题。
    % 速度：v=w*v+c1*U1.*(pbest-z)+c2*U2.*(gbest-z)，位置：z=z+v。
    % 每代采用同步更新；个体最优严格改善才替换，相同值保留较早历史点。
    % 输入state为空表示初始化；非空时必须先重评全部历史最优和当前位置。
    n = numel(z0);
    count = o.swarm_size;
    evaluations = 0;
    repairs = 0;
    invalid = 0;
    generations = 0;
    trace = struct([]);
    history = zeros(0, 3 + n);
    % 列：代数、评价次数、最优罚值、最优z。
    audit = struct('old_values', [], 'memory_positions', [], ...
        'new_memory_values', [], 'current_positions', [], ...
        'new_current_values', [], 'memory_rechecks', 0, 'current_rechecks', 0);

    if isempty(state)
        if isfield(o, 'initial_search_positions')
            positions = o.initial_search_positions;
        else
            positions = rand(stream, n, count);
        end
        positions(:, 1) = z0;
        velocities = o.velocity_limit * (2 * rand(stream, n, count) - 1);
        pbest = positions;
    else
        positions = state.positions;
        velocities = state.velocities;
        pbest = state.pbest;
        audit.old_values = state.values;
        audit.memory_positions = pbest;
    end
    initialPositions = positions;
    scores = Inf(1, count);
    details = cell(1, count);

    % 旧罚值只留作审计，绝不参与新罚系数下的优劣比较。
    if ~isempty(state)
        for i = 1:count
            if evaluations >= o.max_evaluations
                break;
            end
            [scores(i), details{i}] = evaluate(pbest(:, i));
            audit.memory_rechecks = audit.memory_rechecks + 1;
        end
        audit.new_memory_values = scores;
    end
    currentScores = Inf(1, count);

    for i = 1:count
        if evaluations >= o.max_evaluations
            break;
        end
        [currentScores(i), currentDetail] = evaluate(positions(:, i));
        audit.current_rechecks = audit.current_rechecks + 1;

        if currentScores(i) < scores(i)
            scores(i) = currentScores(i);
            pbest(:, i) = positions(:, i);
            details{i} = currentDetail;
        end
    end
    audit.current_positions = positions;
    audit.new_current_values = currentScores;
    [bestValue, bestIndex] = min(scores);
    best = pbest(:, bestIndex);
    bestDetail = details{bestIndex};

    if ~isfinite(bestValue)
        % 保留异常状态供上层处理，不能将全部无效的粒子当作收敛。
        result = package('nonfinite_initial');
        return;
    end
    remember(0);
    status = 'generation_limit';

    for generation = 1:o.max_generations
        if evaluations >= o.max_evaluations
            status = 'evaluation_budget';
            break;
        end
        fraction = (generation - 1) / max(1, o.max_generations - 1);
        inertia = o.inertia_start + fraction * (o.inertia_end - o.inertia_start);
        velocities = inertia * velocities ...
            + o.cognitive * rand(stream, n, count) .* (pbest - positions) ...
            + o.social * rand(stream, n, count) .* (best - positions);
        velocities = min(o.velocity_limit, max(-o.velocity_limit, velocities));
        positions = positions + velocities;
        repaired = 0;
        if strcmp(o.boundary_mode, 'clip')
            [positions, velocities, repaired] = repair_box(positions, velocities);
        end
        repairs = repairs + repaired;

        for i = 1:count
            if evaluations >= o.max_evaluations
                break;
            end
            [value, detail] = evaluate(positions(:, i));

            if value < scores(i)
                scores(i) = value;
                pbest(:, i) = positions(:, i);
                details{i} = detail;
            end
        end
        [bestValue, bestIndex] = min(scores);
        best = pbest(:, bestIndex);
        bestDetail = details{bestIndex};
        generations = generation;
        history(end + 1, :) = [generation, evaluations, bestValue, best']; %#ok<AGROW>
        if mod(generation, o.trace_stride) == 0
            remember_trace(generation);
        end
        if size(history, 1) > o.stall_generations
            pastValue = history(end - o.stall_generations, 3);
            improvement = pastValue - bestValue;
            spread = max(abs(positions - best), [], 'all');

            if improvement <= o.fitness_tolerance * max(1, abs(bestValue)) ...
                && spread <= o.swarm_tolerance
                status = 'swarm_stagnation';
                break;
            end
        end
    end
    if evaluations >= o.max_evaluations
        status = 'evaluation_budget';
    end
    if trace(end).evaluations ~= evaluations
        remember_trace(generations);
    end
    result = package(status);

    function [value, detail] = evaluate(point)
        % PSO只请求函数值和原始约束，不计算/使用解析梯度。
        evaluations = evaluations + 1;
        [value, ~, detail] = fun(point);

        if ~isfinite(value) || ~isreal(value)
            value = Inf;
            invalid = invalid + 1;
        end
    end

    function remember(iteration)
        history(end + 1, :) = [iteration, evaluations, bestValue, best'];
        remember_trace(iteration);
    end

    function remember_trace(iteration)
        row = struct('iteration', iteration, 'evaluations', evaluations, ...
            'phi', bestValue, 'z', best, 'detail', bestDetail);
        trace = [trace; row];
    end

    function r = package(exitStatus)
        nextState = struct('positions', positions, 'velocities', velocities, ...
            'pbest', pbest, 'values', scores);
        r = struct('z', best, 'value', bestValue, 'detail', bestDetail, ...
            'state', nextState, 'status', exitStatus, 'evaluations', evaluations, ...
            'gradient_evaluations', 0, 'generations', generations, ...
            'trace', trace, 'history', history, 'memory_audit', audit, ...
            'boundary_repairs', repairs, 'nonfinite_evaluations', invalid, ...
            'initial_positions', initialPositions);
    end
end

function [z, v, repaired] = repair_box(z, v)
    % 只处理归一化计算边界[0,1]；非线性约束仍完全交给共同罚函数。
    % 触边时截到边界，并清零继续朝外的速度分量。
    outside = z < 0 | z > 1;
    outward = (z < 0 & v < 0) | (z > 1 & v > 0);
    repaired = nnz(outside);
    z = min(1, max(0, z));
    v(outward) = 0;
end

%% 新增直接法：课件复合形法；G05使用等式可行性恢复扩展
function o = complex_options(id)
    % 基本搜索对应第4章第46、51--57页；恢复模块属于本作业的明确扩展。
    % 原有两套方法的参数不变；本方法沿用同题的联合评价上限。
    common = experiment_options(id, 0);
    o = struct('max_evaluations', common.max_evaluations, ...
        'max_iterations', 20000, 'reflection', 1.3, 'contraction', 0.5, ...
        'max_reflections', 35, 'max_repairs', 35, 'max_initial_draws', 50000, ...
        'function_tolerance', 1e-10, 'space_tolerance', 1e-6, ...
        'g_tolerance', 1e-8, 'h_tolerance', 1e-8, 'bound_tolerance', 1e-8, ...
        'trace_stride', 10, 'restore_iterations', 40, 'restore_backtracks', 20, ...
        'difference_step', 1e-6, 'normal_step_limit', 0.25);
end

function d = raw_model_detail(p, z)
    % 只评价原目标和原约束，不构造任何罚函数、不计算目标梯度。
    x = p.lb + (p.ub - p.lb) .* z;
    [f, g, h] = model_eval(p, x, false);
    d = struct('x', x, 'f', f, 'g', g, 'h', h, ...
        'max_g', max([0; g]), 'max_h', max([0; abs(h)]), ...
        'max_bound', max([0; p.lb - x; x - p.ub]));
end

function yes = complex_feasible(d, o)
    % 搜索内部采用较严格的可行阈值；事后达标判据继续用既有原始单位标准。
    yes = all(isfinite([d.f; d.g; d.h])) && d.max_g <= o.g_tolerance ...
        && d.max_h <= o.h_tolerance && d.max_bound <= o.bound_tolerance;
end

function [z, d, info] = restore_equalities(fun, p, z, o)
    % 辅助恢复：只降低h的残差，不查看原目标f的大小或目标梯度。
    % 差分形成Je=dh_scaled/dz，最小范数步为 -pinv(Je)*h_scaled。
    % 线性系统求解与回溯只处理等式；原目标的搜索仍由复合形反射完成。
    % fun必须是计数回调，差分、回溯和失败试探都会计入总预算。
    info = struct('status', 'restore_limit', 'iterations', 0, 'jacobian_builds', 0);
    d = [];
    z = min(1, max(0, z));
    try
        d = fun(z);
        for iteration = 1:o.restore_iterations
            if d.max_h <= o.h_tolerance
                info.status = 'equality_restored';
                return;
            end
            e = d.h ./ p.h_scale;
            J = zeros(numel(e), p.n);
            for j = 1:p.n
                plus = z;
                minus = z;
                plus(j) = min(1, z(j) + o.difference_step);
                minus(j) = max(0, z(j) - o.difference_step);
                dp = fun(plus);
                dm = fun(minus);
                J(:, j) = ((dp.h - dm.h) ./ p.h_scale) / (plus(j) - minus(j));
            end
            info.jacobian_builds = info.jacobian_builds + 1;
            step = -pinv(J) * e;
            stepNorm = norm(step, inf);
            if any(~isfinite(step)) || stepNorm < 1e-15
                info.status = 'restore_stalled';
                return;
            end
            step = step * min(1, o.normal_step_limit / stepNorm);
            oldResidual = e' * e;
            accepted = false;
            alpha = 1;
            for backtrack = 1:o.restore_backtracks
                trial = min(1, max(0, z + alpha * step));
                next = fun(trial);
                residual = next.h ./ p.h_scale;
                if residual' * residual < (1 - 1e-4 * alpha) * oldResidual ...
                        || next.max_h <= o.h_tolerance
                    z = trial;
                    d = next;
                    accepted = true;
                    break;
                end
                alpha = alpha / 2;
            end
            info.iterations = iteration;
            if ~accepted
                info.status = 'restore_stalled';
                return;
            end
        end
        if d.max_h <= o.h_tolerance
            info.status = 'equality_restored';
        end
    catch err
        if ~strcmp(err.identifier, 'coursework:ComplexBudget'), rethrow(err); end
        info.status = 'evaluation_budget';
    end
end

function run = complex_minimize(p, z0, o, seed)
    % 课件复合形核心：K=2n个可行顶点，反射最坏点；不改善则缩小映射系数。
    % 最坏点方向无效时尝试次坏点方向（课件第54--55页），有限次失败则记录退出。
    % G05的恢复函数仅求可行点；没有调用BFGS、PSO或fmincon优化原目标。
    validateattributes(z0, {'double'}, ...
        {'column', 'numel', p.n, 'real', 'finite', '>=', 0, '<=', 1});
    stream = RandStream('mt19937ar', 'Seed', seed);
    count = 2 * p.n;
    positions = zeros(p.n, count);
    values = Inf(1, count);
    filled = 0;
    evaluations = 0;
    initializationCost = 0;
    initialized = false;
    iterations = 0;
    repairs = 0;
    restoreCalls = 0;
    restoreCost = 0;
    restoreIterations = 0;
    jacobianBuilds = 0;
    projectionCalls = 0;
    projectionIterations = 0;
    restoreFailures = 0;
    acceptedReflections = 0;
    secondWorstAttempts = 0;
    bestZ = z0;
    bestDetail = [];
    fallback = [];
    trace = struct([]);
    history = zeros(0, 6 + p.n);
    status = 'iteration_limit';
    timer = tic;

    try
        % 初始可行点：只从共同z0和固定种子的随机点开始，不注入参考解。
        for attempt = 1:o.max_initial_draws
            if attempt == 1, candidate = z0; else, candidate = rand(stream, p.n, 1); end
            [point, d, valid] = repair(candidate, []);
            if valid
                positions(:, 1) = point;
                values(1) = d.f;
                filled = 1;
                consider(point, d);
                break;
            end
        end
        if filled == 0
            status = 'feasible_initialization_failed';
        else
            for j = 2:count
                center = feasible_center(positions(:, 1:filled));
                [point, d, valid] = repair(rand(stream, p.n, 1), center);
                if ~valid
                    status = 'feasible_initialization_failed';
                    break;
                end
                positions(:, j) = point;
                values(j) = d.f;
                filled = j;
                consider(point, d);
            end
            initialized = filled == count;
            initializationCost = evaluations;
        end
        remember(0);

        if initialized
            for iteration = 1:o.max_iterations
                [~, bestIndex] = min(values);
                diameter = max(abs(positions - positions(:, bestIndex)), [], 'all');
                spread = max(values) - min(values);
                if diameter <= o.space_tolerance ...
                        && spread <= o.function_tolerance * max(1, abs(bestDetail.f))
                    status = 'complex_collapsed';
                    break;
                end
                [~, order] = sort(values, 'descend');
                accepted = false;
                for direction = 1:min(2, count)
                    bad = order(direction);
                    if direction == 2, secondWorstAttempts = secondWorstAttempts + 1; end
                    others = true(1, count);
                    others(bad) = false;
                    center = feasible_center(positions(:, others));
                    alpha = o.reflection;
                    for reflection = 1:o.max_reflections
                        trial = center + alpha * (center - positions(:, bad));
                        [point, d, valid] = repair(trial, center);
                        if valid && d.f < values(bad)
                            positions(:, bad) = point;
                            values(bad) = d.f;
                            consider(point, d);
                            acceptedReflections = acceptedReflections + 1;
                            accepted = true;
                            break;
                        end
                        alpha = alpha * o.contraction;
                    end
                    if accepted, break; end
                end
                iterations = iteration;
                history(end + 1, :) = history_row(iteration); %#ok<AGROW>
                if mod(iteration, o.trace_stride) == 0, remember_trace(iteration); end
                if ~accepted
                    status = 'reflection_stalled';
                    break;
                end
            end
        end
    catch err
        if ~strcmp(err.identifier, 'coursework:ComplexBudget'), rethrow(err); end
        status = 'evaluation_budget';
    end
    if ~initialized, initializationCost = evaluations; end
    if isempty(bestDetail)
        bestDetail = fallback;
        bestZ = z0;
    end
    if isempty(trace) || trace(end).evaluations ~= evaluations
        remember_trace(iterations);
    end
    if isempty(history) || history(end, 2) ~= evaluations
        history(end + 1, :) = history_row(iterations);
    end
    run = struct('method', 'complex_direct', 'z', bestZ, 'final_detail', bestDetail, ...
        'status', status, 'trace', trace, 'history', history, 'evaluations', evaluations, ...
        'gradient_evaluations', 0, 'constraint_jacobian_builds', jacobianBuilds, ...
        'initialization_evaluations', initializationCost, 'iterations', iterations, ...
        'accepted_reflections', acceptedReflections, 'second_worst_attempts', secondWorstAttempts, ...
        'feasibility_repairs', repairs, 'restoration_calls', restoreCalls, ...
        'restoration_evaluations', restoreCost, 'restoration_iterations', restoreIterations, ...
        'restoration_failures', restoreFailures, 'vertices', positions(:, 1:filled), ...
        'vertex_values', values(1:filled), 'seed', seed, 'seconds', toc(timer));
    if isfield(o, 'projection') && o.projection
        run.projection_calls = projectionCalls;
        run.projection_scalar_iterations = projectionIterations;
    end

    function d = evaluate(point)
        if evaluations >= o.max_evaluations
            error('coursework:ComplexBudget', 'Complex-method evaluation budget exhausted.');
        end
        evaluations = evaluations + 1;
        d = raw_model_detail(p, point);
        if isempty(fallback), fallback = d; end
    end

    function [point, d, valid] = repair(point, center)
        point = min(1, max(0, point));
        valid = false;
        for cut = 0:o.max_repairs
            % 没有剩余预算时不进入恢复模块，也不增加一次零成本恢复调用。
            if evaluations >= o.max_evaluations
                error('coursework:ComplexBudget', 'No budget left for a repair evaluation.');
            end
            if isempty(p.h_scale)
                if isfield(o, 'projection') && o.projection
                    [point, countIterations] = project_parabolic(p, point);
                    projectionCalls = projectionCalls+1;
                    projectionIterations = projectionIterations+countIterations;
                end
                d = evaluate(point);
            else
                before = evaluations;
                restoreCalls = restoreCalls + 1;
                [point, d, info] = restore_equalities(@evaluate, p, point, o);
                restoreCost = restoreCost + evaluations - before;
                restoreIterations = restoreIterations + info.iterations;
                jacobianBuilds = jacobianBuilds + info.jacobian_builds;
                if strcmp(info.status, 'evaluation_budget')
                    error('coursework:ComplexBudget', 'Budget exhausted during equality restoration.');
                end
                if ~strcmp(info.status, 'equality_restored'), restoreFailures = restoreFailures + 1; end
            end
            valid = complex_feasible(d, o);
            if valid || isempty(center), return; end
            point = center + o.contraction * (point - center);
            repairs = repairs + 1;
        end
    end

    function center = feasible_center(points)
        center = mean(points, 2);
        if isempty(p.h_scale), return; end
        [center, ~, valid] = repair(center, bestZ);
        % 非线性等式下中心未必可行；恢复失败时退回已确认的最好可行顶点。
        if ~valid, center = bestZ; end
    end

    function consider(point, d)
        if isempty(bestDetail) || d.f < bestDetail.f
            bestZ = point;
            bestDetail = d;
        end
    end

    function row = history_row(iteration)
        d = bestDetail;
        if isempty(d), d = fallback; end
        row = [iteration, evaluations, d.f, d.max_g, d.max_h, d.max_bound, bestZ'];
    end

    function remember(iteration)
        history(end + 1, :) = history_row(iteration);
        remember_trace(iteration);
    end

    function remember_trace(iteration)
        d = bestDetail;
        if isempty(d), d = fallback; end
        row = struct('iteration', iteration, 'evaluations', evaluations, ...
            'f', d.f, 'max_g', d.max_g, 'max_h', d.max_h, ...
            'max_bound', d.max_bound, 'z', bestZ, 'x', d.x);
        trace = [trace; row];
    end
end

%% 统一模型、罚函数与事后评价
function p = problem_definition(id)
    % 参考解仅供自检与事后评价；两套求解器的初始化和停止均不读取它。
    id = upper(char(id));

    switch id
        case 'A'
            p = struct('id', 'A', 'n', 2, 'lb', [-1; -1], 'ub', [2; 2], ...
                'f_scale', 1, 'g_scale', ones(3, 1), 'h_scale', zeros(0, 1), ...
                'reference_x', [1; 0], 'reference_f', 1, 'objective_tolerance', 1e-4);

        case 'B'
            p = struct('id', 'B', 'n', 6, 'lb', -ones(6, 1), 'ub', 2*ones(6, 1), ...
                'f_scale', 3, 'g_scale', ones(9, 1), 'h_scale', zeros(0, 1), ...
                'reference_x', repmat([1; 0], 3, 1), 'reference_f', 3, 'objective_tolerance', 1e-4);

        case 'C'
            % 严格等式数值参考仅在事后评价和自检中使用。
            p = struct('id', 'C', 'n', 4, 'lb', [0; 0; -.55; -.55], 'ub', [1200; 1200; .55; .55], ...
                'f_scale', 1e4, 'g_scale', ones(2, 1), 'h_scale', 1000*ones(3, 1), ...
                'reference_x', [679.94532073605683; 1026.0671316649825; ...
                .1188763638621132; -.396233553502708], ...
                'reference_f', 5126.49810959527, 'objective_tolerance', 1e-2);

        otherwise
            error('coursework:Problem', 'Unknown problem: %s', id);
    end
end

function [f, g, h, df, Jg, Jh] = model_eval(p, x, withDerivatives)
    % 原始变量下的统一模型：g<=0、h=0；Jacobian每一行对应一个约束。
    % withDerivatives=false时只计算函数和约束，供不使用梯度的PSO调用。
    if nargin<3
        withDerivatives = true;
    end
    validateattributes(x, {'double'}, {'vector', 'numel', p.n, 'real', 'finite'});
    x = x(:);
    df = [];
    Jg = [];
    Jh = [];

    switch p.id
        case 'A'
            f = (x(1)-2)^2+x(2)^2;
            g = [-x(1); -x(2); x(1)^2+x(2)-1];
            h = zeros(0, 1);

            if withDerivatives
                df = [2*(x(1)-2); 2*x(2)];
                Jg = [-1, 0; 0, -1; 2*x(1), 1];
                Jh = zeros(0, 2);
            end
        case 'B'
            u = x(1:2:end);
            v = x(2:2:end);
            L = [1, -1, 0; -1, 2, -1; 0, -1, 1];
            f = sum((u-2).^2+v.^2+sin(3*pi*u).^2)+5*sum(diff(u).^2+diff(v).^2);
            g = zeros(9, 1);

            for j = 1:3
                rows = 3*j-2:3*j;
                g(rows) = [-u(j); -v(j); u(j)^2+v(j)-1];
            end
            h = zeros(0, 1);

            if withDerivatives
                df = zeros(6, 1);
                df(1:2:end) = 2*(u-2)+3*pi*sin(6*pi*u)+10*L*u;
                df(2:2:end) = 2*v+10*L*v;
                Jg = zeros(9, 6);

                for j = 1:3
                    cols = 2*j-1:2*j;
                    rows = 3*j-2:3*j;
                    Jg(rows, cols) = [-1, 0; 0, -1; 2*u(j), 1];
                end
                Jh = zeros(0, 6);
            end
        case 'C'
            a = x(3);
            b = x(4);
            f = 3*x(1)+1e-6*x(1)^3+2*x(2)+(2e-6/3)*x(2)^3;
            g = [a-b-.55; b-a-.55];
            h = [1000*sin(-a-.25)+1000*sin(-b-.25)+894.8-x(1); ...
                1000*sin(a-.25)+1000*sin(a-b-.25)+894.8-x(2); ...
                1000*sin(b-.25)+1000*sin(b-a-.25)+1294.8];

            if withDerivatives
                df = [3+3e-6*x(1)^2; 2+2e-6*x(2)^2; 0; 0];
                Jg = [0, 0, 1, -1; 0, 0, -1, 1];
                Jh = [-1, 0, -1000*cos(-a-.25), -1000*cos(-b-.25); ...
                    0, -1, 1000*(cos(a-.25)+cos(a-b-.25)), -1000*cos(a-b-.25); ...
                    0, 0, -1000*cos(b-a-.25), 1000*(cos(b-.25)+cos(b-a-.25))];
            end
    end
end

function [phi, gradient, d] = penalty_eval(p, z, r, withDerivatives)
    % 两套方法共用二次外罚框架（课件第4章第119、144页）。
    % x=lb+(ub-lb).*z；phi=f/sf+r*(sum(max(0,c).^2)+sum(e.^2))。
    % c同时包含原不等式和计算边界；e为缩放后的等式残差。
    % G05目标含三次项：另加四次越界保护，避免负向无穷处二次罚项压不住目标。
    % 此项仅在计算边界外生效；边界内的值和梯度均为0，不改变原有约束模型。
    if nargin<4
        withDerivatives = true;
    end
    validateattributes(r, {'double'}, {'scalar', 'real', 'finite', 'positive'});
    z = z(:);
    width = p.ub-p.lb;
    x = p.lb+width.*z;
    [f, g, h, df, Jg, Jh] = model_eval(p, x, withDerivatives);
    c = [g./p.g_scale; -z; z-1];
    e = h./p.h_scale;
    pos = max(0, c);
    phi = f/p.f_scale+r*(pos'*pos+e'*e);
    if strcmp(p.id, 'C')
        lowerViolation = max(0, -z);
        upperViolation = max(0, z-1);
        phi = phi+r*sum(lowerViolation.^4+upperViolation.^4);
    end
    gradient = [];

    if withDerivatives
        Jc = [Jg.*width'./p.g_scale; -eye(p.n); eye(p.n)];
        Je = Jh.*width'./p.h_scale;
        gradient = width.*df/p.f_scale+2*r*(Jc'*pos+Je'*e);
        if strcmp(p.id, 'C')
            gradient = gradient+4*r*(upperViolation.^3-lowerViolation.^3);
        end
    end
    d = struct('x', x, 'f', f, 'g', g, 'h', h, 'df', df, 'Jg', Jg, 'Jh', Jh, ...
        'max_g', max([0; g]), 'max_h', max([0; abs(h)]), ...
        'max_bound', max([0; p.lb-x; x-p.ub]));
end

function m = quality_metrics(p, d)
    % 先判原约束与边界，再判原目标误差；满足一阶条件不等于全局成功。
    % G05主评价采用1e-4等式容差，另外保留1e-6严格诊断；两者分别报告。
    mainFeasible = d.max_g <= 1e-6 && d.max_bound <= 1e-8 && d.max_h <= 1e-4;
    strictFeasible = mainFeasible && d.max_h <= 1e-6;
    err = d.f-p.reference_f;
    m = struct('f', d.f, 'objective_signed_error', err, 'objective_absolute_error', abs(err), ...
        'solution_error', norm(d.x-p.reference_x, inf), 'max_g', d.max_g, ...
        'max_h', d.max_h, 'max_bound', d.max_bound, 'main_feasible', mainFeasible, ...
        'strict_feasible', strictFeasible, 'success', mainFeasible && abs(err) <= p.objective_tolerance, ...
        'objective_hessian_min_eigenvalue', NaN);

    if strcmp(p.id, 'B')
        u = d.x(1:2:end);
        L = [1, -1, 0; -1, 2, -1; 0, -1, 1];
        Huu = diag(2+18*pi^2*cos(6*pi*u))+10*L;
        m.objective_hessian_min_eigenvalue = min([eig(Huu); eig(2*eye(3)+10*L)]);
    end
end

function audit = recheck_wolfe(trace, o)
    % 用保存的点、梯度和函数值重新检验Wolfe不等式，不直接相信求解器标志。
    checked = 0;
    violations = 0;
    minArmijo = Inf;
    minCurvature = Inf;

    for j = 2:numel(trace)
        old = trace(j-1);
        now = trace(j);

        if now.iteration <= 0 || now.stage ~= old.stage
            continue;
        end
        if isfield(now, 'search_z')
            s = now.search_z-old.search_z;
        else
            s = now.z-old.z;
        end
        armijo = old.phi+o.c1*(old.gradient'*s)-now.phi;
        curvature = o.c2*abs(old.gradient'*s)-abs(now.gradient'*s);
        roundoff = 64*eps*max([1, abs(old.phi), abs(now.phi)]);
        checked = checked+1;
        violations = violations+(armijo < -roundoff || curvature < -roundoff);
        minArmijo = min(minArmijo, armijo);
        minCurvature = min(minCurvature, curvature);
    end
    audit = struct('steps_checked', checked, 'violations', violations, ...
        'minimum_armijo_slack', minArmijo, 'minimum_curvature_slack', minCurvature, ...
        'roundoff_policy', '64*eps*max(1,abs(phi_old),abs(phi_new))');
end

function k = kkt_diagnostic(p, d)
    % 在原始单位下识别近似活跃约束，用最小二乘估计乘子。
    % 等式乘子无符号限制，不等式乘子应非负；这里只检查近似一阶必要条件。
    active = d.g >= -1e-5;
    low = d.x-p.lb <= 1e-5;
    high = p.ub-d.x <= 1e-5;
    I = eye(p.n);
    A = [d.Jg(active, :)', d.Jh', -I(:, low), I(:, high)];

    if isempty(A)
        multipliers = zeros(0, 1);
    else
        multipliers = -pinv(A)*d.df;
    end
    ng = sum(active);
    nh = numel(d.h);
    nl = sum(low);
    nonnegative = [multipliers(1:ng); multipliers(ng+nh+1:end)];
    products = [multipliers(1:ng).*d.g(active); ...
        multipliers(ng+nh+(1:nl)).*(p.lb(low)-d.x(low)); ...
        multipliers(ng+nh+nl+1:end).*(d.x(high)-p.ub(high))];
    res = d.df+A*multipliers;
    k = struct('stationarity', norm(res, inf), ...
        'stationarity_relative', norm(res, inf)/max(1, norm(d.df, inf)), ...
        'dual_violation', max([0; -nonnegative]), ...
        'complementarity', max([0; abs(products)]), 'multipliers', multipliers, ...
        'active_inequalities', find(active), 'active_lower', find(low), 'active_upper', find(high));
end

%% 审查回归：预算边缘计数与G05越界罚函数的有界性
function tests = review_selftests
    tests = struct([]);
    p = problem_definition('C');
    o = complex_options('C');
    o.max_evaluations = 1;
    z0 = (p.reference_x - p.lb) ./ (p.ub - p.lb);
    % 参考点只用作单元测试：一次实际调用后预算耗尽，不能再记一次恢复调用。
    tiny = complex_minimize(p, z0, o, 127);
    tests = check(tests, 'Review_no_unfunded_restoration_call', ...
        tiny.evaluations == 1 && tiny.restoration_calls == 1 ...
        && tiny.restoration_evaluations == 1 && tiny.trace(end).evaluations == 1, ...
        tiny.restoration_calls);

    x1 = [-1e5; 600; 0; 0];
    x2 = [-1e6; 600; 0; 0];
    a = penalty_eval(p, (x1 - p.lb) ./ (p.ub - p.lb), 1);
    b = penalty_eval(p, (x2 - p.lb) ./ (p.ub - p.lb), 1);
    tests = check(tests, 'Review_G05_boundary_tail_growth', ...
        isfinite(a) && isfinite(b) && a > 0 && b > a, b);

    % 在越界区独立差分，覆盖新增边界保护项的链式梯度；原始模型不变。
    points = [-.2, .4, .5; .5, 1.1, .5; .3, .4, -.15; .6, .4, 1.2];
    maxError = 0;
    for k = 1:size(points, 2)
        z = points(:, k);
        [~, gradient] = penalty_eval(p, z, 3);
        numeric = zeros(p.n, 1);
        for j = 1:p.n
            dz = zeros(p.n, 1);
            dz(j) = 1e-6;
            numeric(j) = (penalty_eval(p, z + dz, 3) ...
                - penalty_eval(p, z - dz, 3)) / 2e-6;
        end
        maxError = max(maxError, norm(numeric - gradient, inf) / max(1, norm(gradient, inf)));
    end
    tests = check(tests, 'Review_G05_boundary_gradient', maxError < 2e-5, maxError);
    fprintf('REVIEW_SELFTESTS=%d PASS\n', numel(tests));
end

%% 复合形扩展的专项自检：约束恢复、复现、预算与原目标搜索
function tests = complex_selftests
    tests = struct([]);
    p = problem_definition('C');
    o = complex_options('C');
    [z, d, info] = restore_equalities(@(w) raw_model_detail(p, w), p, .5 * ones(4, 1), o);
    tests = check(tests, 'Complex_G05_equality_restoration', ...
        strcmp(info.status, 'equality_restored') && d.max_h <= o.h_tolerance, d.max_h);
    [altered, ~, alteredInfo] = restore_equalities(@(w) relabeled_objective(p, w), ...
        p, .5 * ones(4, 1), o);
    tests = check(tests, 'Complex_restoration_ignores_objective', ...
        isequal(z, altered) && isequal(info, alteredInfo), norm(z - altered, inf));

    p = problem_definition('A');
    o = complex_options('A');
    o.max_evaluations = 10000;
    beforeRng = rng;
    a = complex_minimize(p, [.5; .5], o, 117);
    b = complex_minimize(p, [.5; .5], o, 117);
    metric = quality_metrics(p, a.final_detail);
    tests = check(tests, 'Complex_course_example_target', metric.success, metric.objective_absolute_error);
    tests = check(tests, 'Complex_seed_reproducible', ...
        isequal(a.trace, b.trace) && isequal(a.vertices, b.vertices), a.evaluations);
    tests = check(tests, 'Complex_global_rng_unchanged', isequal(beforeRng, rng), 0);
    tests = check(tests, 'Complex_best_objective_monotone', ...
        all(diff(a.history(:, 3)) <= 0), a.final_detail.f);
    feasible = true;
    for j = 1:size(a.vertices, 2)
        feasible = feasible && complex_feasible(raw_model_detail(p, a.vertices(:, j)), o);
    end
    tests = check(tests, 'Complex_final_vertices_feasible', feasible, size(a.vertices, 2));
    p.reference_x = [-999; 999];
    p.reference_f = -1e20;
    noReference = complex_minimize(p, [.5; .5], o, 117);
    tests = check(tests, 'Complex_reference_not_used_in_search', ...
        isequal(a.trace, noReference.trace), a.evaluations);
    o.max_evaluations = 3;
    tiny = complex_minimize(p, [.5; .5], o, 117);
    tests = check(tests, 'Complex_hard_budget_initialization', ...
        tiny.evaluations == 3 && tiny.trace(end).evaluations == 3 ...
        && strcmp(tiny.status, 'evaluation_budget'), tiny.evaluations);
    p = problem_definition('C');
    o = complex_options('C');
    o.max_evaluations = 7;
    interrupted = complex_minimize(p, .5 * ones(4, 1), o, 117);
    tests = check(tests, 'Complex_hard_budget_during_restoration', ...
        interrupted.evaluations == 7 && interrupted.restoration_evaluations == 7 ...
        && interrupted.trace(end).evaluations == 7 ...
        && strcmp(interrupted.status, 'evaluation_budget'), interrupted.evaluations);
    fprintf('COMPLEX_SELFTESTS=%d PASS\n', numel(tests));
end

function d = relabeled_objective(p, z)
    % 只改变目标值、不改变约束；恢复结果应完全相同，防止辅助步骤偷偷寻优。
    d = raw_model_detail(p, z);
    d.f = -1000 * d.f + 123;
end

%% 自检：小型可验证问题 + 统一模型回归 + PSO机制检查
function tests = pso_selftests
    % 固定小预算验证算法机制，测试样例不计入三道主问题的性能比较。
    tests = struct([]);
    o = pso_options(24);
    o.max_evaluations = 9000;
    o.max_generations = 350;
    beforeRng = rng;
    a = pso_minimize(@box_test, [.8; .2], o, ...
        RandStream('mt19937ar', 'Seed', 71), []);
    b = pso_minimize(@box_test, [.8; .2], o, ...
        RandStream('mt19937ar', 'Seed', 71), []);
    c = pso_minimize(@box_test, [.8; .2], o, ...
        RandStream('mt19937ar', 'Seed', 72), []);
    tests = check(tests, 'PSO_known_box_minimum', ...
        norm(a.z - [.25; .75], inf) < 1e-5 && a.value < 1e-10, a.value);
    tests = check(tests, 'PSO_seed_reproducible', ...
        isequal(a.history, b.history) && isequal(a.state, b.state), a.evaluations);
    tests = check(tests, 'PSO_different_seed_changes_swarm', ...
        ~isequal(a.initial_positions, c.initial_positions), 0);
    tests = check(tests, 'PSO_does_not_change_global_rng', isequal(beforeRng, rng), 0);
    tests = check(tests, 'PSO_best_history_monotone', ...
        all(diff(a.history(:, 3)) <= 0), a.value);
    tests = check(tests, 'PSO_no_gradients', a.gradient_evaluations == 0, 0);
    tiny = o;
    tiny.max_evaluations = 3;
    budget = pso_minimize(@box_test, [.8; .2], tiny, ...
        RandStream('mt19937ar', 'Seed', 71), []);
    tests = check(tests, 'PSO_partial_initialization_budget', ...
        budget.evaluations == 3 && strcmp(budget.status, 'evaluation_budget'), ...
        budget.evaluations);
    tiny.max_evaluations = 29;
    partial = pso_minimize(@box_test, [.8; .2], tiny, ...
        RandStream('mt19937ar', 'Seed', 71), []);
    tests = check(tests, 'PSO_partial_generation_budget', ...
        partial.evaluations == 29 && partial.trace(end).evaluations == 29 ...
        && strcmp(partial.status, 'evaluation_budget'), partial.evaluations);

    % 人工构造错误的旧排序；新目标应选第二个点，且必须重评4次。
    memory = struct('positions', [.8, .2], 'velocities', [0, 0], ...
        'pbest', [.8, .2], 'values', [-100, 100]);
    recheck = pso_options(2);
    recheck.max_evaluations = 4;
    changed = pso_minimize(@memory_test, .5, recheck, ...
        RandStream('mt19937ar', 'Seed', 81), memory);
    tests = check(tests, 'PSO_revalue_old_memory_on_new_penalty', ...
        abs(changed.z - .2) < eps && changed.value == 0 ...
        && changed.evaluations == 4 && changed.memory_audit.memory_rechecks == 2 ...
        && norm(changed.memory_audit.new_memory_values - [.36, 0], inf) < 1e-14, changed.z);
    [position, velocity, repaired] = repair_box([-.2, 1.2, .5], [-1, 1, .1]);
    tests = check(tests, 'PSO_boundary_position_and_velocity', ...
        isequal(position, [0, 1, .5]) && isequal(velocity, [0, 0, .1]) ...
        && repaired == 2, repaired);
    invalidOptions = pso_options(4);
    invalidOptions.max_evaluations = 4;
    bad = pso_minimize(@invalid_test, .5, invalidOptions, ...
        RandStream('mt19937ar', 'Seed', 91), []);
    tests = check(tests, 'PSO_nonfinite_is_not_success', ...
        strcmp(bad.status, 'nonfinite_initial') && bad.nonfinite_evaluations == 4, ...
        bad.nonfinite_evaluations);
    maxDifference = 0;
    ids = {'A', 'B', 'C'};

    for j = 1:numel(ids)
        p = problem_definition(ids{j});

        for t = 1:4
            z = (t / 5) * ones(p.n, 1);
            [phi, ~, d] = penalty_eval(p, z, 10);
            [value, gradient, raw] = penalty_eval(p, z, 10, false);
            maxDifference = max(maxDifference, abs(value - phi));
            assert(isequal([d.f; d.g; d.h], [raw.f; raw.g; raw.h]) && isempty(gradient));
        end
    end
    tests = check(tests, 'PSO_value_only_uses_identical_penalty', maxDifference == 0, maxDifference);
    % 在真实课内模型上跨三层罚系数复现，覆盖外层多样性恢复使用的随机数。
    p = problem_definition('A');
    outerOptions = pso_options(12);
    outerOptions.max_evaluations = 3000;
    outerOptions.max_outer = 3;
    outerOptions.r_max = 100;
    outerA = exterior_pso(p, [.4; .4], outerOptions, 101);
    outerB = exterior_pso(p, [.4; .4], outerOptions, 101);
    tests = check(tests, 'PSO_outer_seed_reproducible', ...
        isequal(outerA.trace, outerB.trace) ...
        && isequal(outerA.final_state, outerB.final_state), outerA.evaluations);
    tests = check(tests, 'PSO_outer_budget_and_trace', ...
        outerA.evaluations <= outerOptions.max_evaluations ...
        && outerA.trace(end).evaluations == outerA.evaluations ...
        && outerA.gradient_evaluations == 0, outerA.evaluations);
    fprintf('PSO_SELFTESTS=%d PASS\n', numel(tests));
end

function [f, g, d] = box_test(x)
    % PSO机制测试用的有界二次函数，已知唯一最优点[0.25;0.75]。
    f = sum((x - [.25; .75]).^2);
    g = [];
    % 特意不提供梯度，验证PSO不依赖梯度。
    d = struct;
end

function [f, g, d] = memory_test(x)
    % 新目标的最优点与人工旧排序冲突，用于捕捉跨罚系数沿用旧值的错误。
    f = (x - .2)^2;
    g = [];
    d = struct;
end

function [f, g, d] = invalid_test(~)
    % 无效函数只用于验证异常状态，不能被记录为成功收敛。
    f = NaN;
    g = [];
    d = struct;
end

function tests = selftests(root)
    % 既有16项第一轮自检：保留全部检查及阈值，验证新增代码没有破坏旧功能。
    tests = struct([]);
    o = default_options;
    o.max_evaluations = 20000;
    q = bfgs_minimize(@quadratic_test, [3; -2], o);
    tests = check(tests, 'BFGS_SPD_quadratic', norm(q.z-[1; -1], inf)<1e-6 && q.value<1e-12, q.value);
    r = bfgs_minimize(@rosenbrock_test, [-1.2; 1], o);
    tests = check(tests, 'BFGS_Rosenbrock', norm(r.z-[1; 1], inf)<1e-5 && r.value<1e-12, r.value);
    tests = check(tests, 'all_test_steps_Wolfe', q.wolfe_violations+r.wolfe_violations == 0, ...
        q.wolfe_steps+r.wolfe_steps);
    oSmall = o;
    oSmall.max_evaluations = 2;
    tiny = bfgs_minimize(@rosenbrock_test, [-1.2; 1], oSmall);
    tests = check(tests, 'hard_budget', tiny.evaluations == 2 ...
        && strcmp(tiny.status, 'evaluation_budget'), tiny.evaluations);
    [f, g] = quadratic_test([3; -2]);
    bad = strong_wolfe(@quadratic_test, [3; -2], f, g, g, o);
    tests = check(tests, 'reject_non_descent', ~bad.success && strcmp(bad.status, 'not_descent'), 0);
    linear = bfgs_minimize(@linear_test, 0, o);
    tests = check(tests, 'line_failure_is_not_success', ...
        strcmp(linear.status, 'line_search_failed'), linear.evaluations);
    domainOptions = o;
    domainOptions.initial_alpha = 16;
    domain = bfgs_minimize(@domain_test, 0, domainOptions);
    tests = check(tests, 'nonfinite_trial_zoom', abs(domain.z-.2)<1e-7 && domain.value<1e-12, domain.value);
    stationary = bfgs_minimize(@quadratic_test, [1; -1], o);
    tests = check(tests, 'stationary_initial', stationary.evaluations == 1 ...
        && stationary.iterations == 0, stationary.evaluations);
    oldPath = fullfile(root, '02_MATLAB验证');
    addpath(oldPath);
    rng(20261025, 'twister');
    ids = {'A', 'B', 'C'};
    maxModelError = 0;
    maxPenaltyError = 0;
    maxFD = 0;

    for j = 1:3
        p = problem_definition(ids{j});

        for t = 1:5
            z = .1+.8*rand(p.n, 1);
            x = p.lb+(p.ub-p.lb).*z;
            [f, g, h, df, Jg, Jh] = model_eval(p, x);
            [a, b, c, d, e, fj] = coursework_problem(p.id, x);
            maxModelError = max(maxModelError, max([0; abs([f; g; h; df; Jg(:); Jh(:)]-[a; b; c; d; e(:); fj(:)])]));
            [phi, grad] = penalty_eval(p, z, 10);
            [oldPhi, oldGrad] = quadratic_penalty(p.id, z, 10);
            maxPenaltyError = max(maxPenaltyError, max(abs([phi; grad]-[oldPhi; oldGrad])));
            numeric = zeros(p.n, 1);

            for col = 1:p.n
                dz = zeros(p.n, 1);
                dz(col) = 1e-7;
                numeric(col) = (penalty_eval(p, z+dz, 10)-penalty_eval(p, z-dz, 10))/2e-7;
            end
            maxFD = max(maxFD, norm(numeric-grad, inf)/max(1, norm(grad, inf)));
        end
        [~, ~, known] = penalty_eval(p, (p.reference_x-p.lb)./(p.ub-p.lb), 10);
        metric = quality_metrics(p, known);
        tests = check(tests, ['reference_metric_', p.id], metric.success, metric.objective_absolute_error);
    end
    tests = check(tests, 'integrated_model_matches_phase1', maxModelError == 0, maxModelError);
    tests = check(tests, 'penalty_inside_box_matches_phase1', maxPenaltyError<1e-10, maxPenaltyError);
    tests = check(tests, 'integrated_penalty_finite_difference', maxFD<2e-5, maxFD);
    p = problem_definition('A');
    [~, ~, d] = penalty_eval(p, ([1+2e-6; 0]-p.lb)./(p.ub-p.lb), 1);
    m = quality_metrics(p, d);
    tests = check(tests, 'objective_alone_cannot_pass', ~m.success && ~m.main_feasible, m.max_g);
    p = problem_definition('C');
    published = [679.945148297028709; 1026.06697600004691; .118876369094410433; -.39623348521517826];
    [~, ~, d] = penalty_eval(p, (published-p.lb)./(p.ub-p.lb), 1);
    m = quality_metrics(p, d);
    tests = check(tests, 'G05_tolerance_not_strict', m.main_feasible && ~m.strict_feasible, m.max_h);
    fprintf('SELFTESTS=%d PASS\n', numel(tests));
end

function tests = check(tests, name, condition, evidence)
    % 每个自检同时保存结论和数值证据；失败即停止，避免继续保存无效批次。
    tests = [tests; struct('Name', name, 'Passed', logical(condition), 'Evidence', evidence)];
    assert(condition, 'coursework:Selftest', 'Selftest failed: %s (%.4e)', name, evidence);
end

function [f, g, d] = quadratic_test(x)
    % BFGS单元检查：正定二次函数，已知最优点[1;-1]。
    Q = [4, 1; 1, 3];
    e = x-[1; -1];
    f = .5*(e'*Q*e);
    g = Q*e;
    d = struct;
end
function [f, g, d] = rosenbrock_test(x)
    % BFGS单元检查：Rosenbrock弯曲谷，检查一维搜索和曲率更新的配合。
    f = 100*(x(2)-x(1)^2)^2+(1-x(1))^2;
    g = [-400*x(1)*(x(2)-x(1)^2)+2*(x(1)-1); 200*(x(2)-x(1)^2)];
    d = struct;
end
function [f, g, d] = linear_test(x)
    % 无下界线性函数无法满足强曲率条件，用于检查失败处理。
    f = -x(1);
    g = -1;
    d = struct;
end
function [f, g, d] = domain_test(x)
    % 故意在定义域外返回Inf/NaN，检查搜索是否能够缩回有效区间。
    if abs(x(1)) >= 1
        f = Inf;
        g = NaN;
    else
        f = (x(1)-.2)^2;
        g = 2*(x(1)-.2);
    end
    d = struct;
end

%% 结果展示：只读已保存数据，图片放临时目录
function show_summary(batch)
    % 显示指定批次汇总，不重新计算、不改变实验数据。
    disp(batch.summary);
    fprintf('ROUND1_VALIDATION_CHECKS=%d\n', batch.checks.all_passed);
    disp(batch.checks);
end

function show_round2(batch)
    % 屏幕只显示关键列，完整误差、约束、成本和状态仍保存在汇总表与原始记录中。
    fprintf('\n第二轮：参数比较（质量分数越小越好）\n');
    disp(batch.parameter_comparison);
    fprintf('独立验证：每题每方法2次，仅用于核对，尚非正式统计。\n');
    disp(batch.validation_summary(:, {'Problem', 'Method', 'Seed', ...
        'ObjectiveError', 'MainFeasible', 'TargetReached', 'Evaluations'}));
    disp(batch.checks);
end

function path = plot_round1(batch, root)
    % 第一轮诊断图：原目标误差/原约束违反量随累计评价次数的变化。
    visible = 'off';
    if usejava('desktop')
        visible = 'on';
    end
    fig = figure('Visible', visible, 'Color', 'w', 'Position', [100, 100, 1350, 1050]);
    tiles = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ids = {'A', 'B', 'C'};

    for k = 1:3
        ax1 = nexttile(tiles);
        hold(ax1, 'on');
        ax2 = nexttile(tiles);
        hold(ax2, 'on');

        for j = 1:numel(batch.runs)
            r = batch.runs{j};
            if ~strcmp(r.problem, ids{k})
                continue;
            end
            p = problem_definition(r.problem);
            t = r.trace;
            evals = [t.evaluations];
            f = [t.f];
            semilogy(ax1, evals, max(abs(f-p.reference_f), 1e-14), 'DisplayName', r.label);
            v = max([[t.max_g]; [t.max_h]; [t.max_bound]], [], 1);
            semilogy(ax2, evals, max(v, 1e-14), 'DisplayName', r.label);
        end
        set([ax1, ax2], 'YScale', 'log');
        grid(ax1, 'on');
        grid(ax2, 'on');
        title(ax1, [ids{k}, ': original objective error']);
        title(ax2, [ids{k}, ': raw constraint violation']);
        xlabel(ax1, 'Cumulative evaluations');
        xlabel(ax2, 'Cumulative evaluations');
        ylabel(ax1, '|f - reference|');
        ylabel(ax2, 'max(g+, |h|, bound violation)');
        legend(ax1, 'Interpreter', 'none', 'Location', 'best');
        legend(ax2, 'Interpreter', 'none', 'Location', 'best');
    end
    title(tiles, 'Round 1: diagnostic starts, exterior penalty + BFGS (not formal comparison)');
    path = fullfile(root, '90_临时文件', 'round1_validation.png');
    exportgraphics(fig, path, 'Resolution', 180);

    if ~usejava('desktop')
        close(fig);
    end
    fprintf('TEMPORARY_FIGURE=%s\n', path);
end

function paths = plot_round3(batch, root)
    % 所有图均从MAT重建；不把不同罚系数的适应度当作同一个目标比较。
    assert(isfield(batch, 'summary_main'), 'Complete numerical analysis before plotting.');
    paths = cell(5, 1);
    colors = [0.10, .35, .75; .85, .25, .10; .10, .55, .20];
    ids = {'A', 'B', 'C'};
    methods = {'BFGS', 'PSO', 'COMPLEX'};
    names = {'外罚+BFGS', '外罚+PSO', '复合形（G05含恢复）'};
    S = batch.summary_main;
    successes = zeros(3);
    costs = zeros(3);
    for k = 1:3
        for m = 1:3
            mask = strcmp(S.Problem, ids{k}) & strcmp(S.Method, methods{m});
            successes(k, m) = 100 * S.Successes(mask) / S.Runs(mask);
            costs(k, m) = S.MedianEval(mask);
        end
    end
    fig = round3_figure([1200, 490]);
    tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
    ax = nexttile;
    bar(ax, successes);
    ylim(ax, [0, 110]);
    set(ax, 'XTickLabel', {'A课内题', 'B非凸题', 'G05'});
    ylabel(ax, '目标达标率（%）');
    title(ax, '可行性与目标精度同时达标；每组30次');
    legend(ax, names, 'Location', 'southoutside');
    ax = nexttile;
    bar(ax, costs);
    set(ax, 'YScale', 'log', 'XTickLabel', {'A课内题', 'B非凸题', 'G05'});
    ylabel(ax, '联合评价次数中位数（对数）');
    title(ax, '含失败试探、初始化及等式恢复成本');
    paths{1} = finish_round3_figure(fig, root, 'round3_01_main.png');

    fig = round3_figure([1320, 430]);
    tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
    T = batch.table_main;
    for k = 1:3
        ax = nexttile;
        hold(ax, 'on');
        for m = 1:3
            mask = strcmp(T.Problem, ids{k}) & strcmp(T.Method, methods{m});
            group = sortrows(T(mask, :), 'Seed');
            jitter = linspace(-.16, .16, height(group))';
            scatter(ax, m + jitter, max(group.AbsError, 1e-12), 23, colors(m, :), 'filled');
            failed = ~group.Success;
            scatter(ax, m + jitter(failed), max(group.AbsError(failed), 1e-12), ...
                50, [0, 0, 0], 'x', 'LineWidth', 1);
        end
        p = problem_definition(ids{k});
        yline(ax, p.objective_tolerance, '--', '目标误差阈值');
        set(ax, 'YScale', 'log', 'XTick', 1:3, 'XTickLabel', {'BFGS', 'PSO', '复合形'});
        xlim(ax, [.5, 3.5]);
        limits = ylim(ax);
        ylim(ax, [limits(1)/2, limits(2)*1.3]); % 留白，避免边界上的散点被裁去一半。
        title(ax, [ids{k}, '：30次输出误差，×为未达标']);
        ylabel(ax, '原目标绝对误差（对数）');
    end
    paths{2} = finish_round3_figure(fig, root, 'round3_02_distribution.png');

    fig = round3_figure([1320, 1100]);
    tiles = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    for k = 1:3
        p = problem_definition(ids{k});
        ax1 = nexttile;
        hold(ax1, 'on');
        ax2 = nexttile;
        hold(ax2, 'on');
        gridPoints = logspace(0, log10(batch.protocol.budgets(k)), 130);
        for m = 1:3
            group = batch.main_runs(cellfun(@(r) strcmp(r.problem, ids{k}) ...
                && strcmp(r.base_method, methods{m}), batch.main_runs));
            errors = NaN(numel(group), numel(gridPoints));
            violations = errors;
            for j = 1:numel(group)
                t = group{j}.trace;
                [x, indexes] = unique([t.evaluations], 'last');
                e = abs([t.f] - p.reference_f);
                v = raw_violation(p, [t.max_g], [t.max_h], [t.max_bound]);
                for q = 1:numel(gridPoints)
                    last = find(x <= gridPoints(q), 1, 'last');
                    if isempty(last), continue; end
                    errors(j, q) = e(indexes(last));
                    violations(j, q) = v(indexes(last));
                end
            end
            % max(NaN,下限)会忽略NaN并产生假值，必须只替换已有的小数值。
            medianError = median(errors, 1, 'omitnan');
            medianViolation = median(violations, 1, 'omitnan');
            medianError(medianError < 1e-12) = 1e-12;
            medianViolation(medianViolation < 1e-8) = 1e-8;
            assert(all(isnan(medianError(all(isnan(errors), 1)))) ...
                && all(isnan(medianViolation(all(isnan(violations), 1)))), ...
                'coursework:PlotMissingData', 'Missing checkpoints must remain NaN.');
            loglog(ax1, gridPoints, medianError, ...
                'Color', colors(m, :), 'LineWidth', 1.7, 'DisplayName', names{m});
            loglog(ax2, gridPoints, medianViolation, ...
                'Color', colors(m, :), 'LineWidth', 1.7, 'DisplayName', names{m});
        end
        set([ax1, ax2], 'XScale', 'log', 'YScale', 'log');
        yline(ax1, p.objective_tolerance, '--', '目标阈值', 'HandleVisibility', 'off');
        yline(ax2, 1, '--', '主可行阈值', 'HandleVisibility', 'off');
        title(ax1, [ids{k}, '：当前检查点的原目标绝对误差中位数']);
        title(ax2, [ids{k}, '：归一化约束违反量中位数']);
        xlabel(ax1, '累计联合评价次数');
        xlabel(ax2, '累计联合评价次数');
        ylabel(ax1, '|f-reference|（可含不可行点）');
        ylabel(ax2, '违反量 / 各自验收容差');
    end
    shared = legend(ax1, 'Location', 'southoutside', 'NumColumns', 3);
    shared.Layout.Tile = 'south';
    title(tiles, '正式30次轨迹；提前结束后保持末值，尚无检查点时不插入虚构值');
    paths{3} = finish_round3_figure(fig, root, 'round3_03_convergence.png');

    fig = round3_figure([1250, 500]);
    tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
    U = batch.summary_multistart;
    labels = strcat(string(U.Method), '/', string(U.Variant));
    ax = nexttile;
    bar(ax, 100 * U.Successes ./ U.Runs);
    ylim(ax, [0, 110]);
    set(ax, 'XTick', 1:height(U), 'XTickLabel', labels, 'XTickLabelRotation', 20);
    ylabel(ax, 'B题目标达标率（%）');
    title(ax, '单起点/单群体与40起点对照，每组30次');
    ax = nexttile;
    bar(ax, U.MedianEval);
    set(ax, 'YScale', 'log', 'XTick', 1:height(U), 'XTickLabel', labels, 'XTickLabelRotation', 20);
    ylabel(ax, '实际联合评价次数中位数');
    title(ax, '总上限均30万；40起点各至多7500次');
    paths{4} = finish_round3_figure(fig, root, 'round3_04_multistart.png');

    fig = round3_figure([1250, 500]);
    tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
    U = batch.summary_sensitivity;
    labels = strcat(string(U.Method), '/', string(U.Variant));
    ax = nexttile;
    bar(ax, 100 * U.Successes ./ U.Runs);
    ylim(ax, [0, 110]);
    set(ax, 'XTick', 1:height(U), 'XTickLabel', labels, 'XTickLabelRotation', 20);
    ylabel(ax, 'G05目标达标率（%）');
    title(ax, '每档同10个种子；当前档取主实验对应运行');
    ax = nexttile;
    bar(ax, max(U.MedianError, 1e-12));
    set(ax, 'YScale', 'log', 'XTick', 1:height(U), 'XTickLabel', labels, 'XTickLabelRotation', 20);
    yline(ax, .01, '--', '目标阈值');
    ylabel(ax, '可行输出目标误差中位数');
    title(ax, '11层、首尾罚系数及50万总预算保持一致');
    paths{5} = finish_round3_figure(fig, root, 'round3_05_sensitivity.png');
end

function fig = round3_figure(sizePixels)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, sizePixels]);
    set(fig, 'DefaultAxesFontName', 'Microsoft YaHei', 'DefaultTextFontName', 'Microsoft YaHei');
end

function path = finish_round3_figure(fig, root, name)
    axesList = findall(fig, 'Type', 'axes');
    for j = 1:numel(axesList), grid(axesList(j), 'on'); end
    path = fullfile(root, '90_临时文件', name);
    exportgraphics(fig, path, 'Resolution', 200);
    close(fig);
    fprintf('ROUND3_FIGURE=%s\n', path);
end

function path = plot_complex(batch, root)
    % 三套方法同一新种子的预实验对照；这里只读取已保存的数值结果。
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1380, 1080]);
    tiles = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ids = {'A', 'B', 'C'};
    styles = {'-', '--'};
    for k = 1:numel(ids)
        left = nexttile(tiles);
        hold(left, 'on');
        right = nexttile(tiles);
        hold(right, 'on');
        for j = 1:numel(batch.validation_runs)
            r = batch.validation_runs{j};
            if ~strcmp(r.problem, ids{k}), continue; end
            p = problem_definition(r.problem);
            switch r.method
                case 'exterior_penalty_bfgs'
                    color = [0.10, 0.35, 0.75];
                    name = '外罚+BFGS';
                case 'exterior_penalty_pso'
                    color = [0.85, 0.25, 0.10];
                    name = '外罚+PSO';
                otherwise
                    color = [0.10, 0.55, 0.20];
                    name = '复合形';
            end
            mask = batch.locked_parameters.validation_seeds == r.initialization_seed;
            style = styles{mask};
            label = sprintf('%s / %d', name, r.initialization_seed);
            t = r.trace;
            loglog(left, [t.evaluations], max(abs([t.f] - p.reference_f), 1e-14), ...
                style, 'Color', color, 'LineWidth', 1.2, 'DisplayName', label);
            violation = max([[t.max_g]; [t.max_h]; [t.max_bound]], [], 1);
            loglog(right, [t.evaluations], max(violation, 1e-14), ...
                style, 'Color', color, 'LineWidth', 1.2, 'DisplayName', label);
        end
        set([left, right], 'XScale', 'log', 'YScale', 'log', 'FontName', 'Microsoft YaHei');
        grid(left, 'on');
        grid(right, 'on');
        title(left, ['问题 ', ids{k}, '：原目标绝对误差']);
        title(right, ['问题 ', ids{k}, '：原始约束违反量']);
        xlabel(left, '累计联合评价次数（含全部恢复成本）');
        xlabel(right, '累计联合评价次数（含全部恢复成本）');
        ylabel(left, '|f - reference|');
        ylabel(right, 'max(g+, |h|, bound violation)');
    end
    % 六条曲线共用底部图例，避免重复的大图例遮住G05末端结果。
    sharedLegend = legend(left, 'Interpreter', 'none', 'NumColumns', 3);
    sharedLegend.Layout.Tile = 'south';
    title(tiles, '第二轮新增复合形法：三套方法配对预实验（非正式统计）');
    path = fullfile(root, '90_临时文件', 'complex_validation.png');
    exportgraphics(fig, path, 'Resolution', 180);
    close(fig);
    fprintf('TEMPORARY_FIGURE=%s\n', path);
end

function path = plot_round2(batch, root)
    % 仅绘制选定参数的留出验证；图不跨罚系数比较罚函数大小。
    % 同一方法两条曲线分别对应两个独立种子；详细数据保存在同一MAT中。
    visible = 'off';

    if usejava('desktop')
        visible = 'on';
    end
    fig = figure('Visible', visible, 'Color', 'w', 'Position', [100, 100, 1380, 1050]);
    tiles = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ids = {'A', 'B', 'C'};

    for k = 1:numel(ids)
        ax1 = nexttile(tiles);
        hold(ax1, 'on');
        ax2 = nexttile(tiles);
        hold(ax2, 'on');

        for j = 1:numel(batch.validation_runs)
            r = batch.validation_runs{j};

            if ~strcmp(r.problem, ids{k})
                continue;
            end
            p = problem_definition(r.problem);
            t = r.trace;
            label = sprintf('%s / seed %d', strrep(r.method, 'exterior_penalty_', ''), ...
                r.initialization_seed);

            if r.swarm_size == 0
                color = [0.10, 0.35, 0.75];
            else
                color = [0.85, 0.25, 0.10];
            end
            styles = {'-', '--'};
            seedMask = batch.locked_parameters.validation_seeds == r.initialization_seed;
            style = styles{seedMask};
            semilogy(ax1, [t.evaluations], max(abs([t.f] - p.reference_f), 1e-14), ...
                style, 'Color', color, 'LineWidth', 1.2, 'DisplayName', label);
            violation = max([[t.max_g]; [t.max_h]; [t.max_bound]], [], 1);
            semilogy(ax2, [t.evaluations], max(violation, 1e-14), ...
                style, 'Color', color, 'LineWidth', 1.2, 'DisplayName', label);
        end
        set([ax1, ax2], 'XScale', 'log', 'YScale', 'log', 'FontName', 'Microsoft YaHei');
        grid(ax1, 'on');
        grid(ax2, 'on');
        title(ax1, ['问题 ', ids{k}, '：原目标绝对误差']);
        title(ax2, ['问题 ', ids{k}, '：原始约束违反量']);
        xlabel(ax1, '累计联合评价次数（对数坐标）');
        xlabel(ax2, '累计联合评价次数（对数坐标）');
        ylabel(ax1, '|f - reference|');
        ylabel(ax2, 'max(g+, |h|, bound violation)');
        legend(ax1, 'Interpreter', 'none', 'Location', 'best');
        legend(ax2, 'Interpreter', 'none', 'Location', 'best');
    end
    title(tiles, sprintf('第二轮独立验证：PSO（%d粒子）与BFGS，非正式统计', ...
        batch.locked_parameters.swarm_size));
    path = fullfile(root, '90_临时文件', 'round2_validation.png');
    exportgraphics(fig, path, 'Resolution', 180);

    if ~usejava('desktop')
        close(fig);
    end
    fprintf('TEMPORARY_FIGURE=%s\n', path);
end

%% 低成本补充：开发集选最小配置，正式结果不参与选参
function output = cost_entry(root, dataPath, mode)
    stored = load(dataPath, 'coursework_results');
    data = stored.coursework_results;
    section = data.improvement;
    b = section.batches{section.latest};
    assert(strcmp(b.status, 'complete') && b.independent_review.all_passed);
    if isfield(data, 'cost_review')
        c = data.cost_review;
        if strcmp(mode, 'summary_cost') || strcmp(c.status, 'complete')
            disp(c.summary_all);
            output = c;
            return;
        end
    else
        assert(~strcmp(mode, 'summary_cost'), 'Run cost_review first.');
        c = struct('version', 'cost-v1', 'status', 'development', ...
            'source_snapshot', fileread(fullfile(root, 'coursework_main.m')), ...
            'training_seeds', 2026102801:2026102805, ...
            'holdout_seeds', 2026102831:2026102835, ...
            'formal_seeds', b.protocol.formal_seeds, ...
            'selection_rule', 'Restarts: smallest passing 8/10 development runs; PSO: smallest passing 4/5 training runs. Fresh holdout gate 3/5; formal outcomes never select parameters.', ...
            'restart_development_seeds', [2026102801:2026102805, 2026102811:2026102815], ...
            'development_note', 'Initial 5-seed restart selection failed its old holdout gate. Those 10 seeds are now development data; five new holdout seeds are reserved.', ...
            'pso_training_runs', {cell(0, 1)}, 'pso_holdout_runs', {cell(0, 1)}, ...
            'restart_holdout_runs', {cell(0, 1)}, ...
            'runs', {cell(0, 1)});
        rows = struct([]);
        choices = {[2, 4, 6, 8, 12, 16], [1, 2, 4, 8, 16]};
        methods = {'BFGS', 'COMPLEX'};
        selected = zeros(1, 2);
        for m = 1:2
            for count = choices{m}
                training = prefix_cohort([b.development_runs; b.holdout_runs], methods{m}, c.restart_development_seeds, count);
                row = struct('Method', methods{m}, 'Starts', count, ...
                    'Successes', sum(cellfun(@(r) r.metrics.success, training)), ...
                    'InitialTrainingSuccesses', sum(cellfun(@(r) r.metrics.success, training(1:5))), ...
                    'FormerHoldoutSuccesses', sum(cellfun(@(r) r.metrics.success, training(6:10))), ...
                    'MedianEval', median(cellfun(@(r) r.evaluations, training)));
                rows = [rows; row]; %#ok<AGROW>
                if selected(m) == 0 && row.Successes >= 8, selected(m) = count; end
            end
            assert(selected(m) > 0, 'No economical restart candidate passed training.');
        end
        c.restart_training = struct2table(rows);
        c.restart_counts = selected;
        c.restart_local_budgets = [7500, 2343];
        holdout = struct([]);
        for m = 1:2
            group = cell(5, 1);
            o = improved_options(b.protocol, 'B', methods{m});
            o.max_evaluations = selected(m)*c.restart_local_budgets(m);
            for j = 1:5
                group{j} = restarted_search('B', methods{m}, c.holdout_seeds(j), o, selected(m));
            end
            c.restart_holdout_runs = [c.restart_holdout_runs; group];
            holdout = [holdout; struct('Method', methods{m}, 'Starts', selected(m), ...
                'Successes', sum(cellfun(@(r) r.metrics.success, group)))]; %#ok<AGROW>
        end
        c.restart_holdout = struct2table(holdout);
        disp(c.restart_training);
        disp(c.restart_holdout);
        assert(all(c.restart_holdout.Successes >= 3), 'Restart holdout gate failed; formal runs have not been inspected.');
        budgets = [3000, 6000, 12000, 24000];
        rows = struct([]);
        c.pso_budget = 0;
        for budget = budgets
            group = cell(5, 1);
            for j = 1:5
                o = improved_options(b.protocol, 'C', 'PSO');
                o.max_evaluations = budget;
                group{j} = execute_round3('C', 'PSO', c.training_seeds(j), o, 'cost_training');
            end
            c.pso_training_runs = [c.pso_training_runs; group];
            row = struct('Budget', budget, 'Successes', sum(cellfun(@(r) r.metrics.success, group)), ...
                'MedianEval', median(cellfun(@(r) r.evaluations, group)));
            rows = [rows; row]; %#ok<AGROW>
            if c.pso_budget == 0 && row.Successes >= 4, c.pso_budget = budget; end
        end
        c.pso_training = struct2table(rows);
        assert(c.pso_budget > 0, 'No economical PSO candidate passed training.');
        for seed = c.holdout_seeds
            o = improved_options(b.protocol, 'C', 'PSO');
            o.max_evaluations = c.pso_budget;
            c.pso_holdout_runs{end+1, 1} = execute_round3('C', 'PSO', seed, o, 'cost_holdout');
        end
        c.pso_holdout_successes = sum(cellfun(@(r) r.metrics.success, c.pso_holdout_runs));
        assert(c.pso_holdout_successes >= 3, 'PSO holdout gate failed; formal runs have not started.');
        c.status = 'locked';
        c.locked_at = char(datetime('now', 'TimeZone', 'Asia/Shanghai'));
        data.cost_review = c;
        save_compact_verified(data, root, dataPath);
        fprintf('COST_LOCKED BFGS_starts=%d COMPLEX_starts=%d PSO_budget=%d\n', selected(1), selected(2), c.pso_budget);
        disp(c.restart_training);
        disp(c.pso_training);
    end
    assert(strcmp(c.source_snapshot, fileread(fullfile(root, 'coursework_main.m'))), 'Frozen cost-review source changed.');
    % B题复用已保存重启的前缀；单起点预算不变，不重复消耗原模型调用。
    methods = {'BFGS', 'COMPLEX'};
    for j = numel(c.runs)+1:90
        seed = c.formal_seeds(ceil(j/3));
        m = mod(j-1, 3)+1;
        if m < 3
            source = b.experiments(cellfun(@(r) strcmp(r.problem, 'B') ...
                && strcmp(r.base_method, methods{m}) && strcmp(r.variant, 'enhanced') ...
                && r.initialization_seed == seed, b.experiments));
            r = restart_prefix(source{1}, c.restart_counts(m));
        else
            o = improved_options(b.protocol, 'C', 'PSO');
            o.max_evaluations = c.pso_budget;
            r = execute_round3('C', 'PSO', seed, o, 'low_cost');
        end
        r.variant = 'low_cost';
        c.runs{j, 1} = r;
        fprintf('LOW_COST %s %s seed=%d target=%d eval=%d\n', r.problem, r.base_method, seed, r.metrics.success, r.evaluations);
    end
    % 未需改进的六个组合复用原正式数据；A复合形恢复为原单起点方案。
    c.existing_indices = find(cellfun(@(r) ...
        (strcmp(r.problem, 'A') && strcmp(r.base_method, 'COMPLEX') && strcmp(r.variant, 'paired_baseline')) ...
        || (strcmp(r.variant, 'enhanced') && ...
        ~((strcmp(r.problem, 'B') && ~strcmp(r.base_method, 'PSO')) ...
        || (strcmp(r.problem, 'C') && strcmp(r.base_method, 'PSO')) ...
        || (strcmp(r.problem, 'A') && strcmp(r.base_method, 'COMPLEX')))), b.experiments));
    combined = [b.experiments(c.existing_indices); c.runs];
    assert(numel(combined) == 270);
    c.table_all = improvement_table(combined);
    c.summary_all = improvement_statistics(combined);
    assert(height(c.summary_all) == 9 && all(c.summary_all.Runs == 30));
    % 三个低成本组合各重跑一次，B题逐字段证明前缀与实际重跑等价。
    same = false(3, 1);
    for m = 1:3
        prior = c.runs{m};
        if m < 3
            repeat = restarted_search('B', methods{m}, c.formal_seeds(1), prior.options, c.restart_counts(m));
            same(m) = isequaln(prior.trace, repeat.trace) && isequaln(prior.final_detail, repeat.final_detail) ...
                && all(cellfun(@(s, t) isequaln(remove_times(s), remove_times(t)), prior.restarts, repeat.restarts));
        else
            repeat = execute_round3('C', 'PSO', c.formal_seeds(1), prior.options, 'low_cost');
            same(m) = isequaln(remove_times(prior), remove_times(repeat));
        end
    end
    assert(all(same) && all(cellfun(@round3_check_run, c.runs)));
    c.reproduction_checks = same;
    c.status = 'complete';
    c.completed_at = char(datetime('now', 'TimeZone', 'Asia/Shanghai'));
    c.code_review = review_sources(root);
    data.cost_review = c;
    save_compact_verified(data, root, dataPath);
    disp(c.summary_all);
    output = c;
end

function group = prefix_cohort(runs, method, seeds, count)
    group = cell(numel(seeds), 1);
    for j = 1:numel(seeds)
        source = runs(cellfun(@(r) strcmp(r.problem, 'B') && strcmp(r.base_method, method) ...
            && r.initialization_seed == seeds(j), runs));
        assert(numel(source) == 1);
        group{j} = restart_prefix(source{1}, count);
    end
end

function r = restart_prefix(source, count)
    % 仅截取既有固定重启序列，保持所有子运行的点、参数、种子和数据。
    r = source;
    r.restarts = source.restarts(1:count);
    r.restart_count = count;
    r.options.max_evaluations = count*r.restarts{1}.options.max_evaluations;
    r.trace = source.trace(1:count);
    r.evaluations = sum(cellfun(@(s) s.evaluations, r.restarts));
    r.gradient_evaluations = sum(cellfun(@(s) s.gradient_evaluations, r.restarts));
    r.seconds = sum(cellfun(@(s) s.seconds, r.restarts));
    r.wall_seconds = NaN; % 前缀包装层未单独计时；求解器计时是已实测子运行之和。
    r.projection_calls = 0;
    r.projection_scalar_iterations = 0;
    if strcmp(r.base_method, 'COMPLEX')
        r.projection_calls = sum(cellfun(@(s) s.projection_calls, r.restarts));
        r.projection_scalar_iterations = sum(cellfun(@(s) s.projection_scalar_iterations, r.restarts));
    end
    best = r.restarts{1};
    p = problem_definition(r.problem);
    for j = 2:count
        if prefer_raw(r.restarts{j}.final_detail, best.final_detail, p), best = r.restarts{j}; end
    end
    r.z = best.z;
    r.final_detail = best.final_detail;
    r.metrics = best.metrics;
    r.variant = 'low_cost';
    r.verified = round3_check_run(r);
    assert(r.verified);
end

function save_compact_verified(data, root, dataPath)
    % 压缩存储与算法改进分开；加载后逐字段相等才替换正式文件。
    coursework_results = data;
    pending = fullfile(root, '90_临时文件', 'coursework_results_pending.mat');
    info = whos('coursework_results');
    fileFormat = '-v7';
    if info.bytes > 1.8e9, fileFormat = '-v7.3'; end
    save(pending, 'coursework_results', fileFormat);
    verified = load(pending, 'coursework_results');
    assert(isequaln(coursework_results, verified.coursework_results));
    [ok, message] = movefile(pending, dataPath, 'f');
    assert(ok, message);
end

function path = plot_cost(c, b, root)
    % 同一批种子的原方案、高预算改进、低成本配置；原始记录不重复存储。
    ids = {'A', 'B', 'C'};
    methods = {'BFGS', 'PSO', 'COMPLEX'};
    colors = [.5, .55, .62; .15, .4, .75; .1, .6, .3];
    fig = round3_figure([1500, 850]);
    tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
    for k = 1:3
        rates = zeros(3, 3);
        costs = rates;
        for m = 1:3
            S = b.summary_comparison;
            rows = strcmp(S.Problem, ids{k}) & strcmp(S.Method, methods{m});
            high = S(rows & strcmp(S.Variant, 'enhanced'), :);
            base = S(rows & strcmp(S.Variant, 'paired_baseline'), :);
            if isempty(base), base = high; end
            low = c.summary_all(strcmp(c.summary_all.Problem, ids{k}) & strcmp(c.summary_all.Method, methods{m}), :);
            rates(m, :) = [base.Successes, high.Successes, low.Successes];
            costs(m, :) = [base.MedianEval, high.MedianEval, low.MedianEval];
        end
        ax = nexttile(k);
        bars = bar(ax, rates);
        for j = 1:3, bars(j).FaceColor = colors(j, :); end
        set(ax, 'XTickLabel', {'BFGS', 'PSO', '复合形'}, 'YLim', [0, 33]);
        ylabel(ax, '达标次数 / 30');
        name = ids{k};
        if k == 3, name = 'G05'; end
        title(ax, [name, '：成功率与成本折中']);
        if k == 1, legend(ax, {'原方案', '高预算改进', '低成本配置'}, 'Location', 'southoutside'); end
        ax = nexttile(k+3);
        bars = bar(ax, costs);
        for j = 1:3, bars(j).FaceColor = colors(j, :); end
        set(ax, 'YScale', 'log', 'XTickLabel', {'BFGS', 'PSO', '复合形'});
        ylabel(ax, '联合评价次数中位数（对数坐标）');
        title(ax, [name, '：全部初始化、重启与坐标转换均计入']);
    end
    path = finish_round3_figure(fig, root, 'cost_01_tradeoff.png');
end
