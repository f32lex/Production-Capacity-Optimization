%% ========================================================================
%  Production Capacity Optimization in a Sequential Manufacturing Facility
%  Using Linear Programming
%  ========================================================================
%  Products: Premium 360 (x1), Standard 180 (x2), Partial (x3)
%  Stages:   Material Prep, Disassembly, Fabrication, Assembly, QC
%  ========================================================================

clc; clear; close all;

%% ========== PHASE 1: SYSTEM CHARACTERIZATION & DATA ==========

fprintf('============================================================\n');
fprintf(' PHASE 1: SYSTEM CHARACTERIZATION & DATA\n');
fprintf('============================================================\n\n');

% Processing times (days per unit)
%            Premium  Standard  Partial
T = [  3,       3,       3;    % Stage 1: Material Preparation
       3,       3,       3;    % Stage 2: Disassembly
      30,      20,      10;    % Stage 3: Fabrication
      20,      15,      15;    % Stage 4: Assembly
       3,       3,       3];   % Stage 5: Quality Control

% Simultaneous capacity (units)
C_slots = [3; 3; 3; 2; 1];

% Production period
period = 30; % days

products = {'Premium 360', 'Standard 180', 'Partial'};
stages   = {'Material Prep', 'Disassembly', 'Fabrication', 'Assembly', 'Quality Control'};

[m, n] = size(T);

fprintf('Products: %d | Stages: %d | Period: %d days\n\n', n, m, period);
fprintf('%-20s %10s %10s %10s %10s\n', 'Stage', products{:}, 'Capacity');
for i = 1:m
    fprintf('%-20s %10d %10d %10d %10d\n', stages{i}, T(i,:), C_slots(i));
end

%% ========== PHASE 2: LP MODEL FORMULATION ==========

fprintf('\n============================================================\n');
fprintf(' PHASE 2: LP MODEL FORMULATION\n');
fprintf('============================================================\n\n');

A_ub = T / period;
b_ub = C_slots;

fprintf('Constraint Coefficients (t_ij / %d):\n', period);
fprintf('%-20s %10s %10s %10s %6s %6s\n', 'Stage', 'x1', 'x2', 'x3', '<=', 'C_i');
for i = 1:m
    fprintf('%-20s %10.4f %10.4f %10.4f %6s %6.1f\n', ...
        stages{i}, A_ub(i,1), A_ub(i,2), A_ub(i,3), '<=', b_ub(i));
end

lb = zeros(n, 1);
ub = [];
Aeq = [];
beq = [];
options = optimoptions('linprog', 'Algorithm', 'dual-simplex', 'Display', 'off');

%% ========== PHASE 3A: EQUAL WEIGHTS (Throughput Max) ==========

fprintf('\n============================================================\n');
fprintf(' PHASE 3A: EQUAL WEIGHTS - Max Total Throughput\n');
fprintf(' Objective: Maximize Z = x1 + x2 + x3\n');
fprintf('============================================================\n\n');

f1 = -[1; 1; 1];
[x1_opt, fval1, ~, ~, lam1] = linprog(f1, A_ub, b_ub, Aeq, beq, lb, ub, options);

for j = 1:n
    fprintf('  x%d (%-14s) = %.4f units/month\n', j, products{j}, x1_opt(j));
end
Z1 = -fval1;
fprintf('\n  Maximum Z = %.4f total units per month\n', Z1);

usage1 = A_ub * x1_opt;
slack1 = b_ub - usage1;
fprintf('\n  Constraint Analysis:\n');
for i = 1:m
    if abs(slack1(i)) < 1e-6
        status = '<-- BOTTLENECK';
    else
        status = '';
    end
    fprintf('  %-20s Usage=%.4f/%.0f  Slack=%.4f  %s\n', ...
        stages{i}, usage1(i), b_ub(i), slack1(i), status);
end

%% ========== PHASE 3B: PREMIUM PRIORITY (Weighted) ==========

fprintf('\n============================================================\n');
fprintf(' PHASE 3B: PREMIUM PRIORITY - Weighted Objective\n');
fprintf(' Objective: Maximize Z = 3x1 + 2x2 + 1x3\n');
fprintf(' (Premium weighted highest to reflect demand priority)\n');
fprintf('============================================================\n\n');

f2 = -[3; 2; 1];
[x2_opt, fval2, ~, ~, lam2] = linprog(f2, A_ub, b_ub, Aeq, beq, lb, ub, options);

for j = 1:n
    fprintf('  x%d (%-14s) = %.4f units/month\n', j, products{j}, x2_opt(j));
end
fprintf('\n  Total units   = %.4f\n', sum(x2_opt));
fprintf('  Weighted Z    = %.4f\n', -fval2);

usage2 = A_ub * x2_opt;
slack2 = b_ub - usage2;
fprintf('\n  Constraint Analysis:\n');
for i = 1:m
    if abs(slack2(i)) < 1e-6
        status = '<-- BOTTLENECK';
    else
        status = '';
    end
    fprintf('  %-20s Usage=%.4f/%.0f  Slack=%.4f  %s\n', ...
        stages{i}, usage2(i), b_ub(i), slack2(i), status);
end

fprintf('\n  Shadow Prices:\n');
sp2 = -lam2.ineqlin;
for i = 1:m
    fprintf('  %-20s %.4f\n', stages{i}, sp2(i));
end

%% ========== PHASE 3C: LEXICOGRAPHIC - Premium First ==========

fprintf('\n============================================================\n');
fprintf(' PHASE 3C: LEXICOGRAPHIC - Maximize Premium FIRST\n');
fprintf('============================================================\n\n');

% Step 1: Maximize Premium alone
f3a = [-1; 0; 0];
[x3a, fval3a] = linprog(f3a, A_ub, b_ub, Aeq, beq, lb, ub, options);
max_prem = x3a(1);
fprintf('  Step 1: Maximum Premium possible = %.4f units\n', max_prem);

% Step 2: Fix x1 = max_premium, maximize x2 + x3
Aeq2 = [1, 0, 0];
beq2 = max_prem;
f3b = [0; -1; -1];
[x3b, fval3b] = linprog(f3b, A_ub, b_ub, Aeq2, beq2, lb, ub, options);
fprintf('  Step 2: With Premium fixed at %.0f:\n', max_prem);
for j = 1:n
    fprintf('    x%d (%-14s) = %.4f\n', j, products{j}, x3b(j));
end
fprintf('    Total units   = %.4f\n', sum(x3b));

usage3 = A_ub * x3b;
slack3 = b_ub - usage3;
fprintf('\n  Constraint Analysis:\n');
for i = 1:m
    if abs(slack3(i)) < 1e-6
        status = '<-- BOTTLENECK';
    else
        status = '';
    end
    fprintf('  %-20s Usage=%.4f/%.0f  Slack=%.4f  %s\n', ...
        stages{i}, usage3(i), b_ub(i), slack3(i), status);
end

%% ========== TABULAR SIMPLEX (Premium Priority) ==========

fprintf('\n============================================================\n');
fprintf(' TABULAR SIMPLEX METHOD - Premium Priority (3:2:1)\n');
fprintf('============================================================\n');

num_vars = n + m;
tableau = zeros(m + 1, num_vars + 1);
tableau(1:m, 1:n) = A_ub;
tableau(1:m, n+1:n+m) = eye(m);
tableau(1:m, end) = b_ub;
tableau(end, 1:n) = -[3, 2, 1];

var_names = {'x1', 'x2', 'x3', 's1', 's2', 's3', 's4', 's5'};
basis = {'s1', 's2', 's3', 's4', 's5'};

print_tableau(tableau, basis, var_names, 0, m);

for iter = 1:20
    obj_row = tableau(end, 1:end-1);
    [min_val, pivot_col] = min(obj_row);

    if min_val >= -1e-10
        fprintf('\n>> OPTIMAL at Iteration %d.\n', iter-1);
        break;
    end

    ratios = inf(m, 1);
    for i = 1:m
        if tableau(i, pivot_col) > 1e-10
            ratios(i) = tableau(i, end) / tableau(i, pivot_col);
        end
    end
    [~, pivot_row] = min(ratios);

    fprintf('\n  Pivot: %s enters, %s leaves\n', var_names{pivot_col}, basis{pivot_row});

    pivot_val = tableau(pivot_row, pivot_col);
    tableau(pivot_row, :) = tableau(pivot_row, :) / pivot_val;
    for i = 1:(m+1)
        if i ~= pivot_row
            tableau(i, :) = tableau(i, :) - tableau(i, pivot_col) * tableau(pivot_row, :);
        end
    end
    basis{pivot_row} = var_names{pivot_col};
    print_tableau(tableau, basis, var_names, iter, m);
end

fprintf('\nFinal: Z = %.4f\n', tableau(end, end));
for i = 1:m
    fprintf('  %s = %.4f\n', basis{i}, tableau(i, end));
end

%% ========== PHASE 4: SENSITIVITY ANALYSIS ==========

fprintf('\n============================================================\n');
fprintf(' PHASE 4: SENSITIVITY ANALYSIS (Under Premium Priority)\n');
fprintf('============================================================\n\n');

Z_base = sum(x2_opt);

% 4a: Bottleneck capacity increases
fprintf('--- 4a. Binding Stage Capacity Increase ---\n');
fprintf('(Fabrication AND Assembly are both binding)\n\n');

fprintf('Fabrication +1 slot (3 -> 4):\n');
b_new = b_ub; b_new(3) = 4;
[x_new, ~] = linprog(f2, A_ub, b_new, Aeq, beq, lb, ub, options);
fprintf('  Premium=%.2f, Standard=%.2f, Partial=%.2f, Total=%.2f\n', ...
    x_new(1), x_new(2), x_new(3), sum(x_new));

fprintf('\nAssembly +1 slot (2 -> 3):\n');
b_new = b_ub; b_new(4) = 3;
[x_new, ~] = linprog(f2, A_ub, b_new, Aeq, beq, lb, ub, options);
fprintf('  Premium=%.2f, Standard=%.2f, Partial=%.2f, Total=%.2f\n', ...
    x_new(1), x_new(2), x_new(3), sum(x_new));

fprintf('\nBoth Fabrication +1 AND Assembly +1:\n');
b_new = b_ub; b_new(3) = 4; b_new(4) = 3;
[x_new, ~] = linprog(f2, A_ub, b_new, Aeq, beq, lb, ub, options);
fprintf('  Premium=%.2f, Standard=%.2f, Partial=%.2f, Total=%.2f\n', ...
    x_new(1), x_new(2), x_new(3), sum(x_new));

% 4b: Individual +1 slot
fprintf('\n--- 4b. Individual Stage +1 Slot ---\n');
fprintf('%-20s %8s %8s %8s %8s %8s\n', 'Stage', 'Premium', 'Std', 'Partial', 'Total', 'Change');
fprintf('%s\n', repmat('-', 1, 60));
for i = 1:m
    b_new = b_ub;
    b_new(i) = b_ub(i) + 1;
    [x_new, ~] = linprog(f2, A_ub, b_new, Aeq, beq, lb, ub, options);
    Z_new = sum(x_new);
    fprintf('%-20s %8.2f %8.2f %8.2f %8.2f %+8.2f\n', ...
        stages{i}, x_new(1), x_new(2), x_new(3), Z_new, Z_new - Z_base);
end

% 4c: Processing time +/-10%
fprintf('\n--- 4c. Processing Time +/-10%% ---\n');
fprintf('%-20s %15s %15s %10s\n', 'Stage', '-10% -> Total', '+10% -> Total', 'Sensitive?');
fprintf('%s\n', repmat('-', 1, 65));
for i = 1:m
    T_new = T; T_new(i,:) = T(i,:) * 0.9;
    A_new = T_new / period;
    [x_m, ~] = linprog(f2, A_new, b_ub, Aeq, beq, lb, ub, options);

    T_new = T; T_new(i,:) = T(i,:) * 1.1;
    A_new = T_new / period;
    [x_p, ~] = linprog(f2, A_new, b_ub, Aeq, beq, lb, ub, options);

    if abs(sum(x_m) - Z_base) > 1e-6 || abs(sum(x_p) - Z_base) > 1e-6
        sens = 'YES';
    else
        sens = 'No';
    end
    fprintf('%-20s %15.4f %15.4f %10s\n', stages{i}, sum(x_m), sum(x_p), sens);
end

% 4d: Proportional increase
fprintf('\n--- 4d. Proportional Capacity Increase (All Stages) ---\n');
fprintf('%-12s %10s %10s %10s %10s\n', 'Increase', 'Premium', 'Total', 'Change', '% Change');
fprintf('%s\n', repmat('-', 1, 55));
for pct = [10, 20, 30, 50, 100]
    b_new = b_ub * (1 + pct/100);
    [x_new, ~] = linprog(f2, A_ub, b_new, Aeq, beq, lb, ub, options);
    Z_new = sum(x_new);
    fprintf('+%-11d%% %9.2f %9.2f %+9.2f %9.1f%%\n', ...
        pct, x_new(1), Z_new, Z_new - Z_base, (Z_new-Z_base)/Z_base*100);
end

%% ========== COMPARISON SUMMARY ==========

fprintf('\n============================================================\n');
fprintf(' SCENARIO COMPARISON SUMMARY\n');
fprintf('============================================================\n\n');
fprintf('%-30s %8s %8s %8s %8s\n', 'Scenario', 'Premium', 'Standard', 'Partial', 'Total');
fprintf('%s\n', repmat('-', 1, 65));
fprintf('%-30s %8.2f %8.2f %8.2f %8.2f\n', '1. Equal weights', x1_opt(1), x1_opt(2), x1_opt(3), sum(x1_opt));
fprintf('%-30s %8.2f %8.2f %8.2f %8.2f\n', '2. Premium priority (3:2:1)', x2_opt(1), x2_opt(2), x2_opt(3), sum(x2_opt));
fprintf('%-30s %8.2f %8.2f %8.2f %8.2f\n', '3. Premium-first lexicographic', x3b(1), x3b(2), x3b(3), sum(x3b));

%% ========== FIGURES ==========

fprintf('\n============================================================\n');
fprintf(' GENERATING FIGURES\n');
fprintf('============================================================\n\n');

% Figure 1: Capacity Utilization (Premium Priority)
figure('Name', 'Capacity Utilization', 'Position', [100 100 800 500]);
util_pct = (usage2 ./ b_ub) * 100;
b1 = bar(util_pct);
b1.FaceColor = 'flat';
for i = 1:m
    if util_pct(i) >= 99.9
        b1.CData(i,:) = [0.85 0.15 0.15];
    else
        b1.CData(i,:) = [0.18 0.33 0.59];
    end
end
set(gca, 'XTickLabel', stages, 'FontSize', 11);
ylabel('Capacity Utilization (%)', 'FontSize', 12);
title('Stage Capacity Utilization - Premium Priority', 'FontSize', 14);
yline(100, '--r', 'Full Capacity', 'LineWidth', 1.5);
ylim([0 120]);
grid on;
for i = 1:m
    text(i, util_pct(i) + 3, sprintf('%.1f%%', util_pct(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
end
saveas(gcf, 'Fig1_Capacity_Utilization.png');
fprintf('Saved: Fig1_Capacity_Utilization.png\n');

% Figure 2: Scenario Comparison
figure('Name', 'Scenario Comparison', 'Position', [100 100 800 500]);
scenario_data = [x1_opt'; x2_opt'; x3b'];
bar_h = bar(scenario_data);
set(gca, 'XTickLabel', {'Equal Weights', 'Premium Priority (3:2:1)', 'Premium-First Lexico.'}, 'FontSize', 10);
ylabel('Units per Month', 'FontSize', 12);
title('Product Mix by Optimization Scenario', 'FontSize', 14);
legend(products, 'Location', 'northwest');
grid on;
saveas(gcf, 'Fig2_Scenario_Comparison.png');
fprintf('Saved: Fig2_Scenario_Comparison.png\n');

% Figure 3: Shadow Prices (Premium Priority)
figure('Name', 'Shadow Prices', 'Position', [100 100 800 500]);
b3 = bar(sp2);
b3.FaceColor = 'flat';
for i = 1:m
    if sp2(i) > 1e-6
        b3.CData(i,:) = [0.85 0.15 0.15];
    else
        b3.CData(i,:) = [0.7 0.7 0.7];
    end
end
set(gca, 'XTickLabel', stages, 'FontSize', 11);
ylabel('Shadow Price', 'FontSize', 12);
title('Shadow Prices - Premium Priority Scenario', 'FontSize', 14);
grid on;
for i = 1:m
    text(i, sp2(i) + 0.08, sprintf('%.2f', sp2(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
end
saveas(gcf, 'Fig3_Shadow_Prices.png');
fprintf('Saved: Fig3_Shadow_Prices.png\n');

% Figure 4: Individual +1 Slot Impact
figure('Name', 'Stage Impact', 'Position', [100 100 800 500]);
delta_Z = zeros(m, 1);
for i = 1:m
    b_new = b_ub;
    b_new(i) = b_ub(i) + 1;
    [x_new, ~] = linprog(f2, A_ub, b_new, Aeq, beq, lb, ub, options);
    delta_Z(i) = sum(x_new) - Z_base;
end
b4 = bar(delta_Z);
b4.FaceColor = 'flat';
for i = 1:m
    if delta_Z(i) > 1e-6
        b4.CData(i,:) = [0 0.69 0.31];
    else
        b4.CData(i,:) = [0.7 0.7 0.7];
    end
end
set(gca, 'XTickLabel', stages, 'FontSize', 11);
ylabel('Additional Units per Month', 'FontSize', 12);
title('Impact of +1 Slot at Each Stage - Premium Priority', 'FontSize', 14);
grid on;
for i = 1:m
    text(i, delta_Z(i) + 0.05, sprintf('+%.2f', delta_Z(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
end
saveas(gcf, 'Fig4_Stage_Impact.png');
fprintf('Saved: Fig4_Stage_Impact.png\n');

fprintf('\n>> DONE.\n');

%% ========== HELPER FUNCTION ==========

function print_tableau(tab, basis, var_names, iteration, m)
    fprintf('\n--- Tableau: Iteration %d ---\n', iteration);
    header = sprintf('%-6s', 'Basis');
    for v = 1:length(var_names)
        header = [header, sprintf(' %9s', var_names{v})];
    end
    header = [header, sprintf(' %9s', 'RHS')];
    fprintf('%s\n', header);
    fprintf('%s\n', repmat('-', 1, length(header)));
    for i = 1:m
        row_str = sprintf('%-6s', basis{i});
        for j = 1:size(tab, 2)
            row_str = [row_str, sprintf(' %9.4f', tab(i,j))];
        end
        fprintf('%s\n', row_str);
    end
    row_str = sprintf('%-6s', 'Z');
    for j = 1:size(tab, 2)
        row_str = [row_str, sprintf(' %9.4f', tab(end,j))];
    end
    fprintf('%s\n', row_str);
end
