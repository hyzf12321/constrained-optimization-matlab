function paths = plot_public_results
% PLOT_PUBLIC_RESULTS 从公开MAT重建四组图，不运行优化或修改数据。
    root = fileparts(mfilename('fullpath'));
    saved = load(fullfile(root, '03_验证结果', 'coursework_results.mat'), 'coursework_results');
    d = saved.coursework_results;
    b = d.improvement.batches{d.improvement.latest};
    c = d.cost_review;
    runs = [b.experiments(c.existing_indices); c.runs];
    assert(numel(runs) == 270 && height(c.table_all) == 270);
    out = fullfile(root, 'figures');
    if ~isfolder(out), mkdir(out); end
    ids = {'A', 'B', 'C'};
    labels = {'A', 'B', 'G05'};
    methods = {'BFGS', 'PSO', 'COMPLEX'};
    colors = [.15 .4 .75; .85 .3 .1; .1 .6 .3];
    refs = [1, 3, 5126.49810959527];
    tolerances = [1e-4, 1e-4, 1e-2];
    paths = cell(4, 1);

    fig = new_figure([1400 480]);
    tiles = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
    T = c.table_all;
    for k = 1:3
        ax = nexttile; hold(ax, 'on');
        for m = 1:3
            rows = strcmp(T.Problem, ids{k}) & strcmp(T.Method, methods{m});
            group = sortrows(T(rows, :), 'Seed');
            assert(height(group) == 30);
            scatter(ax, m+linspace(-.15,.15,30)', max(group.AbsError,1e-12), ...
                28, colors(m,:), 'filled', 'DisplayName', methods{m});
        end
        yline(ax, tolerances(k), '--', 'Target', 'HandleVisibility', 'off');
        set(ax, 'YScale', 'log', 'XTick', 1:3, 'XTickLabel', methods, 'XLim', [.5 3.5]);
        title(ax, labels{k}); ylabel(ax, 'Absolute objective error'); grid(ax, 'on');
    end
    title(tiles, 'Current configuration: all 30 runs; zero errors shown at 1e-12');
    paths{1} = finish(fig, out, '01_objective_errors.png');

    fig = new_figure([1400 1000]);
    tiledlayout(fig, 3, 2, 'TileSpacing', 'compact');
    seed = min(c.formal_seeds);
    for k = 1:3
        ax1 = nexttile; hold(ax1, 'on');
        ax2 = nexttile; hold(ax2, 'on');
        for m = 1:3
            group = runs(cellfun(@(r) strcmp(r.problem,ids{k}) ...
                && strcmp(r.base_method,methods{m}) && r.initialization_seed == seed, runs));
            assert(numel(group) == 1);
            r = group{1};
            if isfield(r, 'trace_storage')
                assert(strcmp(r.trace_storage, 'columns-v1'));
                ev = r.trace.evaluations(:); f = r.trace.f(:);
                g = r.trace.max_g(:); h = r.trace.max_h(:); bound = r.trace.max_bound(:);
            else
                ev = [r.trace.evaluations]'; f = [r.trace.f]';
                g = [r.trace.max_g]'; h = [r.trace.max_h]'; bound = [r.trace.max_bound]';
            end
            assert(~isempty(ev) && all(diff(ev) >= 0) && ev(end) == r.evaluations);
            violation = max([g/1e-6, bound/1e-8], [], 2);
            if k == 3, violation = max(violation, h/1e-4); end
            loglog(ax1, ev, max(abs(f-refs(k)),1e-12), 'Color', colors(m,:), ...
                'LineWidth', 1.4, 'DisplayName', methods{m});
            loglog(ax2, ev, max(violation,1e-8), 'Color', colors(m,:), ...
                'LineWidth', 1.4, 'DisplayName', methods{m});
        end
        set([ax1 ax2], 'XScale', 'log', 'YScale', 'log');
        yline(ax1,tolerances(k),'--','Target','HandleVisibility','off');
        yline(ax2,1,'--','Feasible','HandleVisibility','off');
        title(ax1,[labels{k} ': objective error']); title(ax2,[labels{k} ': constraint violation']);
        ylabel(ax1,'Absolute error'); ylabel(ax2,'Violation / tolerance');
        for ax = [ax1 ax2], xlabel(ax,'Joint evaluations'); grid(ax,'on'); end
        legend(ax1,'Location','best');
    end
    sgtitle(sprintf('Current configuration, preselected first formal seed %d; recorded checkpoints only',seed));
    paths{2} = finish(fig, out, '02_convergence.png');

    fig = new_figure([1500 850]);
    tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
    for k = 1:3
        successes = zeros(3); costs = zeros(3);
        for m = 1:3
            S = b.summary_comparison;
            rows = strcmp(S.Problem,ids{k}) & strcmp(S.Method,methods{m});
            high = S(rows & strcmp(S.Variant,'enhanced'),:);
            base = S(rows & strcmp(S.Variant,'paired_baseline'),:);
            if isempty(base), base = high; end
            low = c.summary_all(strcmp(c.summary_all.Problem,ids{k}) & strcmp(c.summary_all.Method,methods{m}),:);
            successes(m,:) = [base.Successes high.Successes low.Successes];
            costs(m,:) = [base.MedianEval high.MedianEval low.MedianEval];
        end
        ax = nexttile(k); bar(ax,successes); ylim(ax,[0 33]);
        set(ax,'XTickLabel',methods); ylabel(ax,'Targets reached / 30'); title(ax,labels{k}); grid(ax,'on');
        if k == 1, legend(ax,{'Paired baseline','High budget','Current'},'Location','southoutside'); end
        ax = nexttile(k+3); bar(ax,costs); set(ax,'YScale','log','XTickLabel',methods);
        ylim(ax,[min(costs(:))/2, max(costs(:))*2]);
        ylabel(ax,'Median joint evaluations'); grid(ax,'on');
    end
    paths{3} = finish(fig, out, '03_quality_cost.png');

    fig = new_figure([1300 500]);
    tiledlayout(fig,1,2,'TileSpacing','compact');
    S = b.summary_ablation;
    ax = nexttile; bar(ax,100*S.Successes./S.Runs); ylim(ax,[0 110]);
    set(ax,'XTick',1:height(S),'XTickLabel',S.Variant,'XTickLabelRotation',15,'TickLabelInterpreter','none');
    ylabel(ax,'Targets reached (%)'); title(ax,'B: projection/restart ablation'); grid(ax,'on');
    ax = nexttile; bar(ax,S.MedianEval); set(ax,'YScale','log','XTick',1:height(S), ...
        'XTickLabel',S.Variant,'XTickLabelRotation',15,'TickLabelInterpreter','none');
    ylabel(ax,'Median joint evaluations'); title(ax,'Same 10 seeds; cap 300000'); grid(ax,'on');
    paths{4} = finish(fig, out, '04_B_ablation.png');
end

function fig = new_figure(sizePixels)
    fig = figure('Visible','off','Color','w','Position',[100 100 sizePixels]);
end

function path = finish(fig, out, name)
    path = fullfile(out,name);
    exportgraphics(fig,path,'Resolution',180);
    close(fig);
    fprintf('PUBLIC_FIGURE=%s\n',name);
end
