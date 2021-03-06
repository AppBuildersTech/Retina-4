classdef CNN < handle
    %CNN implements a Convolutional Neural Network
    
    properties
        % independant
        x                               % x{i} input data 3d matrix (2d spatial + 1d time)
        y                               % y{i} ouput data, 3d matrix (2d spatial + 1d time)
        divide_param                    % structure of 'training ratio', 'validation ratio' and 'test ratio'
        
        kernel_sizes                    % dimenstion of kernel of each layer. 2d matrix, columns (height, width, depth)
        kernel_paths                    % e.x. {'bipolar', 'ganglion'}
        space_value_limits              % for kernel designer. 2d matrix, columns (ymin, ymax)
        time_value_limits               % for kernel designer. 2d matrix, columns (ymin, ymax)
        
        output_size                     % [height, width, depth] of output layer
        resize_method                   % 'crop', 'nearset', 'bilinear' and 'bicubic'
        
        number_of_epochs                % number of epochs
        batch_size                      % batch size in stochastic gradient descent
        learning_rate                   % learning rate in gradient descent
        number_of_validations_faild     % termination condition in the rule 'no improvement after number_of_validations_faild epochs'
        
        C                               % cost function
        C_                              % derivative of cost function
        s                               % activation function
        s_                              % derivative of activation function
        
        % dependant
        L                               % number of layers
        input_size                      % size of input layer := [height, width, depth]
        layers                          % dimenstion of each layer except input layer. 2d matrix, columns (height, width, depth)
        
        w                               % w{l} kernel of l'th layer (3d matrix := 2d spatial + 1d time)
        dw                              % dw{l} is used in learning rule : w{l} = w{l} - learning_rage * dw{l}
        b                               % b{l} bias of l'th layer
        db                              % db{l} is used in learning rule : b{l} = b{l} - learning_rage * db{l}
        z                               % z{l} net input of l'th layer
        a                               % a{l} activation of l'th layer
        d                               % d{l} error of l'th layer
        
        data                            % structure of 'train', 'validation' and 'test'
        history                         % history for each epoch
        index_min_cost_validation       % epoch number that network has minimum cost on validation data
        
    end
    
    methods
        function obj = CNN()
            obj.x = [];
            obj.y = [];
            obj.divide_param.train_ratio = 70/100;
            obj.divide_param.validation_ratio = 15/100;
            obj.divide_param.test_ratio = 15/100;
            
            obj.kernel_sizes = [];
            obj.kernel_paths = [];
            obj.space_value_limits = [];
            obj.time_value_limits = [];
            obj.output_size = [];
            obj.resize_method = 'crop';

            obj.number_of_epochs = 100;
            obj.batch_size = 1;
            obj.learning_rate = 0.001;
            obj.number_of_validations_faild = 6;
            
            obj.C = @CNN.quadratic_cost_function;
            obj.C_ = @CNN.diff_quadratic_cost_function;
            obj.s = @CNN.rectifier_activation_function;
            obj.s_ = @CNN.diff_rectifier_activation_function;
        end
        
        function init_input_size(obj)
           obj.input_size = obj.output_size + sum(obj.kernel_sizes - 1, 1);
        end
        
        function init_layers(obj)
            obj.layers = zeros(obj.L, 3);
            % first layer
            obj.layers(1, :) = obj.input_size - obj.kernel_sizes(1, :) + 1;
            % other layers
            for l = 2:obj.L
                obj.layers(l, :) = obj.layers(l-1, :) - obj.kernel_sizes(l, :) + 1;
            end 
        end
        
        % todo: refactor resize_input, resize_x and resize_y
        function x = resize_input(obj, x)
            do_crop = strcmp(obj.resize_method, 'crop');
            m = obj.input_size(1);
            n = obj.input_size(2);
            p = obj.input_size(3);
            
            for i = 1:length(x)
                [M, N, P] = size(x{i});
                
                if P > p
                    x{i} = x{i}(:, :, 1:p);
                elseif P < p
                    % concatenate leading zero frames
                    x{i} = cat(3, zeros(M, N, p - P), x{i});
                end
                
                if isequal([M, N], obj.input_size)
                    continue;
                end
                
                % todo: if (M, N) < (m, n) -> resize bigger
                if do_crop
                    m1 = floor((M - m) / 2) + 1;
                    m2 = m1 + m - 1;
                    n1 = floor((N - n) / 2) + 1;
                    n2 = n1 + n - 1;
                    x{i} = x{i}(m1:m2, n1:n2, :);
                else
                    x{i} = imresize(x{i}, obj.input_size, obj.resize_method);
                end
            end
        end
        
        function resize_x(obj)
            do_crop = strcmp(obj.resize_method, 'crop');
            m = obj.input_size(1);
            n = obj.input_size(2);
            p = obj.input_size(3);
            
            for i = 1:length(obj.x)
                [M, N, P] = size(obj.x{i});
                
                if P > p
                    obj.x{i} = obj.x{i}(:, :, 1:p);
                elseif P < p
                    % concatenate leading zero frames
                    obj.x{i} = cat(3, zeros(M, N, p - P), obj.x{i});
                end
                
                if isequal([M, N], obj.input_size)
                    continue;
                end
                
                if do_crop
                    m1 = floor((M - m) / 2) + 1;
                    m2 = m1 + m - 1;
                    n1 = floor((N - n) / 2) + 1;
                    n2 = n1 + n - 1;
                    obj.x{i} = obj.x{i}(m1:m2, n1:n2, :);
                else
                    obj.x{i} = imresize(obj.x{i}, obj.input_size, obj.resize_method);
                end
            end
        end
        
        function resize_y(obj)
            do_crop = strcmp(obj.resize_method, 'crop');
            m = obj.output_size(1);
            n = obj.output_size(2);
            p = obj.output_size(3);
            
            for i = 1:length(obj.y)
                [M, N, P] = size(obj.y{i});
                
                if P > p
                    obj.y{i} = obj.y{i}(:, :, 1:p);
                elseif P < p
                    % concatenate leading zero frames
                    obj.y{i} = cat(3, zeros(M, N, p - P), obj.y{i});
                end
                
                if isequal([M, N], obj.output_size)
                    continue;
                end
                
                if do_crop
                    m1 = floor((M - m) / 2) + 1;
                    m2 = m1 + m - 1;
                    n1 = floor((N - n) / 2) + 1;
                    n2 = n1 + n - 1;
                    obj.y{i} = obj.y{i}(m1:m2, n1:n2, :);
                else
                    obj.y{i} = imresize(obj.y{i}, obj.output_size, obj.resize_method);
                end
            end
        end
        
        function init_w(obj)
            obj.w = cell(obj.L, 1);
            
            if isempty(obj.kernel_paths)
                for l = 1:obj.L
                    obj.w{l} = rand(obj.kernel_sizes(l, :));
                end
            else
                for l = 1:obj.L
                    kd = KernelDesigner.load(obj.kernel_paths{l});
                    obj.w{l} = kd.get_kernel(obj.kernel_sizes(l, :), obj.space_value_limits(l, :), obj.time_value_limits(l, :));
                end
            end
        end
        
        function init_dw(obj)
            obj.dw = cell(size(obj.w));
            for l = 1:length(obj.dw)
                obj.dw{l} = zeros(size(obj.w{l}));
            end
        end
        
        function add_noise_to_w(obj, sigma)
            for l = 1:obj.L
                obj.w{l} = obj.w{l} + sigma * randn(size(obj.w{l}));
            end
        end
        
        function init_b(obj)
            obj.b = cell(obj.L, 1);
            for l = 1:obj.L
                obj.b{l} = rand();
            end
        end
        
        function init_db(obj)
            obj.db = cell(size(obj.b));
            for l = 1:length(obj.db)
                obj.db{l} = zeros(size(obj.b{l}));
            end
        end
        
        function add_noise_to_b(obj, sigma)
            %ADD_NOISE_TO_B add gaussian noise ~ G(0, sigma) to biases
            for l = 1:obj.L
                obj.b{l} = obj.b{l} + sigma * randn(size(obj.b{l}));
            end
        end
        
        function divide_data(obj)
            n = length(obj.x);
            indexes = randperm(n);
            train_index = floor(obj.divide_param.train_ratio * n);
            validation_index = floor((obj.divide_param.train_ratio + obj.divide_param.validation_ratio) * n);
            test_index = n;
            
            obj.data.train.x = obj.x(indexes(1:train_index));
            obj.data.train.y = obj.y(indexes(1:train_index));
            
            obj.data.validation.x = obj.x(indexes(train_index + 1:validation_index));
            obj.data.validation.y = obj.y(indexes(train_index + 1:validation_index));
            
            obj.data.test.x = obj.x(indexes(validation_index + 1:test_index));
            obj.data.test.y = obj.y(indexes(validation_index + 1:test_index));
        end
        
        function make_data(obj, N)
            obj.x = cell(N, 1);
            for i = 1:N
                obj.x{i} = rand(obj.input_size);
            end
            obj.y = obj.out(obj.x);
        end
        
        function init(obj)
            % L
            obj.L = size(obj.kernel_sizes, 1);
            % input size
            obj.init_input_size();
            % layers
            obj.init_layers();
            
            % resize x
            if ~isempty(obj.x)
                obj.resize_x();
            end
            % resize y
            if ~isempty(obj.y)
                obj.resize_y();
            end
            
            % w
            if isempty(obj.w)
                obj.init_w();
            end
            % dw
            if isempty(obj.dw)
                obj.init_dw();
            end
            % b
            if isempty(obj.b)
                obj.init_b();
            end
            % db
            if isempty(obj.db)
                obj.init_db();
            end
            % z
            if isempty(obj.z)
                obj.z = cell(obj.L, 1);
            end
            % a
            if isempty(obj.a)
                obj.a = cell(obj.L, 1);
            end
            % d
            if isempty(obj.d)
                obj.d = cell(obj.L, 1);
            end
            
            % batch_size
            if obj.batch_size < 1
                obj.batch_size = 1;
            end
            if obj.batch_size > length(obj.x)
                obj.batch_size = length(obj.x);
            end
            
            % data
            if ~isempty(obj.x) && ~isempty(obj.y)
                obj.divide_data();
            end
            
            % history
            obj.history = [];
            
            % index_min_cost_validation
            obj.index_min_cost_validation = [];
        end
        
        function forward_step(obj, x)
            x = CNN.normalize(x);
            % z, a
            % --first layer
            obj.z{1} = convn(x, obj.w{1}, 'valid') + obj.b{1};
            obj.z{1} = CNN.normalize(obj.z{1});
            obj.a{1} = obj.s(obj.z{1});
%             obj.a{1} = CNN.normalize(obj.a{1});

            % --
            for l = 2:obj.L
                obj.z{l} = convn(obj.a{l - 1}, obj.w{l}, 'valid') + obj.b{l};
                obj.z{l} = CNN.normalize(obj.z{l});
                obj.a{l} = obj.s(obj.z{l});
%                 obj.a{l} = CNN.normalize(obj.a{l});
            end
        end
        
        function backward_step(obj, y)
            % d
            % --last layer
            obj.d{obj.L} = obj.C_(y, obj.a{obj.L}) .* obj.s_(obj.z{obj.L});
            % --
            for l = (obj.L - 1):-1:1
                obj.d{l} = ...
                    convn(obj.d{l+1}, CNN.flipn(obj.w{l+1}), 'full') ...
                    .* obj.s_(obj.z{l});
            end
        end
        
        function update_dw_db(obj, x)
            % dw
            % --first layer
            obj.dw{1} = obj.dw{1} + convn(CNN.flipn(x), obj.d{1}, 'valid');
            
            % --
            for l = 2:obj.L
                obj.dw{l} = obj.dw{l} + convn(CNN.flipn(obj.a{l-1}), obj.d{l}, 'valid');
            end
            
            % b
            for l = 1:obj.L
                obj.db{l} = obj.db{l} + sum(obj.d{l}(:));
            end
        end
        
        function update_step(obj)
            % w
            for l = 1:obj.L
                obj.w{l} = obj.w{l} - ...
                    (obj.learning_rate * (1 / obj.batch_size) * obj.dw{l});
            end
            
            % init dw
            obj.init_dw()
            
            % b
            for l = 1:obj.L
                obj.b{l} = obj.b{l} - ...
                    (obj.learning_rate * (1 / obj.batch_size) * obj.db{l});
            end
            
            % init db
            obj.init_db()
        end
        
        function y = out(obj, x)
            n = length(x);
            y = cell(n, 1);
            for i = 1:n
                obj.forward_step(x{i});
                y{i} = obj.a{obj.L};
            end
        end
        
        function draw_net(obj, face_alpha)
            if nargin == 1
                face_alpha = 0.8;
            end
            
            scales = obj.input_size;
            for i = 1:obj.L
                scales(end + 1, :) = obj.kernel_sizes(i, :);
                scales(end + 1, :) = obj.layers(i, :);
            end

            face_colors = zeros(size(scales, 1), 3);
            face_colors(1, :) = [1, 0, 0]; % x -> red
            face_colors(2:2:end, :) = repmat([0, 1, 0], obj.L, 1); % kernels -> green
            face_colors(3:2:end, :) = repmat([0, 0, 1], obj.L, 1); % layers -> blue
            
            CNN.draw_cubes(scales, face_colors, face_alpha);
        end
        
        function plot_kernel(obj, l)
            kd = KernelDesigner.load(obj.kernel_paths{l});
            kd.space_df.run();
            kd.time_df.run();
        end
        
        function plot_total_cost_history(obj)
            epochs = 1:length(obj.history);
            epochs = epochs - 1; % start from zero (0, 1, 2, ...)
            total_costs = [obj.history.total_cost];
            
            figure('Name', 'Neural Network - Error', 'NumberTitle', 'off', 'Units', 'normalized', 'OuterPosition', [0.25, 0.25, 0.5, 0.5]);
            
            % train
            plot(epochs, total_costs(1, :), 'LineWidth', 2, 'Color', 'blue');
            set(gca, 'YScale', 'log');
            hold('on');
            % validation
            plot(epochs, total_costs(2, :), 'LineWidth', 2, 'Color', 'green');
            % test
            plot(epochs, total_costs(3, :), 'LineWidth', 2, 'Color', 'red');
            
            % minimum validation error
            % --circle
            circle_x = obj.index_min_cost_validation - 1;
            circle_y = total_costs(2, obj.index_min_cost_validation);
            dark_green = [0.1, 0.8, 0.1];
            scatter(circle_x, circle_y, ...
                'MarkerEdgeColor', dark_green, ...
                'SizeData', 300, ...
                'LineWidth', 2 ...
            );
            
            % --cross lines
            h_ax = gca;
            % ----horizontal line
            line(...
                h_ax.XLim, ...
                [circle_y, circle_y], ...
                'Color', dark_green, ...
                'LineStyle', ':', ...
                'LineWidth', 1.5 ...
            );
            % ----vertical line
            line(...
                [circle_x, circle_x], ...
                h_ax.YLim, ...
                'Color', dark_green, ...
                'LineStyle', ':', ...
                'LineWidth', 1.5 ...
            );
            
            hold('off');
            
            xlabel('Epoch');
            ylabel('Mean Squared Error (mse)');
            min_total_costs_based_validation = obj.history(obj.index_min_cost_validation).total_cost;
            
            title(...
                sprintf('Minimum Validation Error is %.3f at Epoch: %d', ...
                    min_total_costs_based_validation(2), ...
                    obj.index_min_cost_validation - 1 ...
                    ) ...
            );
        
            legend(...
                sprintf('Training (%.3f)', min_total_costs_based_validation(1)), ...
                sprintf('Validation (%.3f)', min_total_costs_based_validation(2)), ...
                sprintf('Test (%.3f)', min_total_costs_based_validation(3)), ...
                'Best' ...
            );
            
            grid('on');
            grid('minor');
        end
        
        %todo regression between two histograms
        function plot_all_regressions(obj)
            figure('Name', 'Neural Network - Regression', 'NumberTitle', 'off', 'Units', 'normalized', 'OuterPosition', [0.25, 0.25, 0.5, 0.5]);
            
            % train
            subplot(2, 2, 1);
            CNN.plot_regression(obj.data.train.y', obj.out(obj.data.train.x)', 'Training', 'blue');
            
            % validation
            subplot(2, 2, 2);
            CNN.plot_regression(obj.data.validation.y', obj.out(obj.data.validation.x)', 'Validation', 'green');
            
            % test
            subplot(2, 2, 3);
            CNN.plot_regression(obj.data.test.y', obj.out(obj.data.test.x)', 'Test', 'red');
            
            % all
            subplot(2, 2, 4);
            CNN.plot_regression(obj.y', obj.out(obj.x)', 'All', 'black');
        end
        
        %todo how to calculate error
        function plot_error_histogram(obj)
            all_errors              = obj.y                 -   obj.out(obj.x);
            train_errors            = obj.data.train.y      -   obj.out(obj.data.train.x);
            validation_errors       = obj.data.validation.y -   obj.out(obj.data.validation.x);
            test_errors             = obj.data.test.y       -   obj.out(obj.data.test.x);
            
            [N, edges] = histcounts(all_errors, 20);
            N_train = histcounts(train_errors, edges);
            N_validation = histcounts(validation_errors, edges);
            N_test = histcounts(test_errors, edges);
            
            % stacked bar plot
            figure('Name', 'Neural Network - Error Histogram', 'NumberTitle', 'off', 'Units', 'normalized', 'OuterPosition', [0.25, 0.25, 0.5, 0.5]);
            bin_centers = (edges(1:end - 1) + edges(2:end)) / 2;
            h = bar(...
                bin_centers, ...
                [N_train', N_validation', N_test'], ...
                'BarLayout', 'stacked' ...
            );
            h(1).FaceColor = 'blue';
            h(2).FaceColor = 'green';
            h(3).FaceColor = 'red';
            
            % zero line
            max_N = max(N);
            line([0, 0], [0, 1.1 * max_N], 'Color', [.8, .4, .2], 'LineWidth', 2);
            set(gca, 'XTick', bin_centers);
            axis('tight');
            
            % legends
            legend('Training', 'Validation', 'Test', 'Zero Error');
        end
        
        
        function total_cost = get_total_cost(obj)
            total_cost = [];
            
            % train
            output = obj.out(obj.data.train.x);
            error = 0;
            n = length(output);
            for i = 1:n
                error = error + obj.C(obj.data.train.y{i}, output{i});
            end
            error = error / n;
            total_cost(end + 1) = error;
            
            % validation
            output = obj.out(obj.data.validation.x);
            error = 0;
            n = length(output);
            for i = 1:n
                error = error + obj.C(obj.data.validation.y{i}, output{i});
            end
            error = error / n;
            total_cost(end + 1) = error;
            
            % test
            output = obj.out(obj.data.test.x);
            error = 0;
            n = length(output);
            for i = 1:n
                error = error + obj.C(obj.data.test.y{i}, output{i});
            end
            error = error / n;
            total_cost(end + 1) = error;
            
            total_cost = total_cost';
        end
        
        function run(obj)
            obj.init();
            
            % 0 epoch
            obj.history(1).total_cost = obj.get_total_cost();
            obj.history(1).w = obj.w;
            obj.history(1).b = obj.b;
            
            obj.index_min_cost_validation = 1;
            n = length(obj.data.train.x);
            batch_index = 0;
%             progress_message = '';
            for epoch = 2:(obj.number_of_epochs + 1)
                % forward, backward, update
                permuted_indexes = randperm(n);
                for i = 1:n
                    index = permuted_indexes(i);
                    obj.forward_step(obj.data.train.x{index});
                    obj.backward_step(obj.data.train.y{index});
                    obj.update_dw_db(obj.data.train.x{index});
                    
                    batch_index = batch_index + 1;
                    if batch_index >= obj.batch_size
                        obj.update_step();
                        batch_index = 0;
                    end
                end
                if batch_index > 0
                    obj.update_step();
                    batch_index = 0;
                end
                % history
                obj.history(epoch).total_cost = obj.get_total_cost();
                obj.history(epoch).w = obj.w;
                obj.history(epoch).b = obj.b;
                
                % no imporovement in number_of_validations_faild steps
                if obj.history(epoch).total_cost(2) < obj.history(obj.index_min_cost_validation).total_cost(2)
                    obj.index_min_cost_validation = epoch;
                end
                
                if (epoch - obj.index_min_cost_validation) >= obj.number_of_validations_faild
                    break;
                end
                
%                 % print epoch number
%                 fprintf(repmat('\b', 1, length(progress_message)));
%                 progress_message = sprintf('Epoch: %d', epoch - 1);
%                 fprintf(progress_message);
            end
%             fprintf('\n');
            
            % best validation performance
            obj.w = obj.history(obj.index_min_cost_validation).w;
            obj.b = obj.history(obj.index_min_cost_validation).b;
        end
        
        function save(obj, filename)
            save(filename, 'obj');
        end
    end
    
    methods (Static)
        %todo change for 3d
        function c = quadratic_cost_function(y, a)
            u = (a - y) .^ 2;
            c = 0.5 * sum(u(:));
        end
        %todo change for 3d
        function c = diff_quadratic_cost_function(y, a)
            c = a - y;
        end
        
        function a = logistic_activation_function(z)
            a = logsig(z);
        end
        
        function a = diff_logistic_activation_function(z)
            u = logsig(z);
            a = u .* (1 - u);
        end
        
        function a = rectifier_activation_function(z)
            a = log(1 + exp(z));
        end
        
        function a = diff_rectifier_activation_function(z)
            a = logsig(z);
        end
        
        function a = tanh_activation_function(z)
            a = 2 * logsig(z) - 1;
        end
        
        function a = diff_tanh_activation_function(z)
            u = logsig(2 * z);
            a = 4 * (u .* (1 - u));
        end
        
        function a = line_activation_function(z)
            a = z;
        end
        
        function a = diff_line_activation_function(z)
            a = ones(size(z));
        end
        
        function plot_regression(target, output, axes_title, color)
            scatter(target, output, 'MarkerEdgeColor', color);
            
            lsline();
            beta = regress(...
                output, ...
                [ones(size(target)), target] ...
            );
            
            title(sprintf('$\\bf{%s~(\\rho:%.2f)}$', axes_title, corr(target, output)), 'Interpreter', 'latex');
            
            xlabel('$Target$', 'Interpreter', 'latex');
            ylabel(sprintf('$o \\approx \\bf{%.2f}~t~+~\\bf{%.3f}$', beta(2), beta(1)), 'Interpreter', 'latex');
            
            legend('Data', 'Fit', 'Location', 'northwest');
            axis('square');
            
        end
        
        function v = make_input(folder_path, filename_extension)
            % default value for filename_extension is 'jpg'
            if nargin == 1
                filename_extension = 'jpg';
            end
            
            % read files
            files = dir([folder_path, '/*.', filename_extension]);
            
            % init v
            I = imread(fullfile(folder_path, files(1).name));
            [m, n] = size(I);
            p = length(files);
            v = zeros(m, n, p);
            
            % make v
            for i = 1:p
                I = imread(fullfile(folder_path, files(i).name));
                I = double(I);
                I = I / max(I(:));

                v(:, :, i) = I;
            end
        end
        
        function movie_3darray(v, delay)
            if nargin == 1
                delay = 0.1;
            end
            
            for i = 1:size(v, 3)
                imshow(v(:, :, i));
                pause(delay);
            end
        end
        
        function movie_slice_3darray(v, delay, edge_color)
            if nargin == 2
                edge_color = false;
            end
            
            if nargin == 1
                delay = 0.1;
            end
            
            [m, n, p] = size(v);
            
            v = permute(v, [2, 3, 1]);
            v = flip(v, 3);
            v = flip(v, 1);

            for i = 1:p
                h = slice(v, i, [], []);
                if ~edge_color
                    set(h, 'EdgeColor', 'none');
                end
                
                xlabel('Frames');
                axis([1, p, 1, n, 1, m]);
                set(gca, ...
                    'XTick', [1, p], 'XTickLabel', [1, p], ...
                    'YTick', [1, n], 'YTickLabel', [n, 1], ...
                    'ZTick', [1, m], 'ZTickLabel', [m, 1] ...
                );
                colormap('gray');
                
                pause(delay);
            end
        end
        
        function plot_slice_3darray(v, number_of_slices, edge_color)
            [m, n, p] = size(v);
            
            if nargin < 2 || number_of_slices > p
                number_of_slices = p;
            end
            
            if nargin < 3
                edge_color = false;
            end
            
            v = permute(v, [2, 3, 1]);
            v = flip(v, 3);
            v = flip(v, 1);
            
            dx = (p - 1) / (number_of_slices - 1);
            sx = 1:dx:p;
            sx = floor(sx);

            h = slice(v, sx, [], [], 'cubic');
            if ~edge_color
                set(h, 'EdgeColor', 'none');
            end
            
            xlabel('Frames');
            axis([1, p, 1, n, 1, m]);
            set(gca, ...
                'XTick', [1, p], 'XTickLabel', [1, p], ...
                'YTick', [1, n], 'YTickLabel', [n, 1], ...
                'ZTick', [1, m], 'ZTickLabel', [m, 1] ...
            );
            colormap('gray');
        end
        
        function draw_cube( scale, translate, face_color, face_alpha, edge_color, line_width )
            %Draw Cubic

            % default parameters
            switch nargin
                case 2
                    face_color = 'blue';
                    face_alpha = 0.8;
                    edge_color = 'black';
                    line_width = 2;
                case 3
                    face_alpha = 0.8;
                    edge_color = 'black';
                    line_width = 2;
                case 4
                    edge_color = 'black';
                    line_width = 2;
                case 5
                    line_width = 2;
            end

            %
            vertices = [
                0 0 0
                0 0 1
                0 1 0
                0 1 1
                1 0 0
                1 0 1
                1 1 0
                1 1 1
            ];

            % vertices = vertices .* repmat(scale, size(vertices, 1), 1);
            % vertices = vertices + repmat(translate, size(vertices, 1), 1);

            vertices = vertices * diag(scale) + translate;

            faces = [
                1 2 4 3
                5 6 8 7
                1 5 6 2
                3 7 8 4
                1 5 7 3
                2 6 8 4
            ];

            patch(...
                'Faces', faces, ...
                'Vertices', vertices, ...
                'FaceColor', face_color, ...
                'FaceAlpha', face_alpha, ...
                'EdgeColor', edge_color, ...
                'LineWidth', line_width ...
            );

            axis('equal');
            view(3);
        end
        
        function draw_cubes( scales, face_colors, face_alpha )
            %Draw Cubes

            % parameters
            font_size = 12;
            font_weight = 'bold';
            x_text = 5;

            %
            figure('Name', 'Cubes', 'NumberTitle', 'off', 'Units', 'Normalized', 'OuterPosition', [0, 0, 1, 1]);
            hold('on');

            M = scales(1, 1);
            N = scales(1, 2);
            scales = flip(scales, 1);
            face_colors = flip(face_colors, 1);
            scales = scales(:, [3, 2, 1]);

            translate = [0, 0, 0];
            for i = 1:size(scales, 1)
                scale = scales(i, :);
                center_translate = ...
                    translate + ...
                    [0, floor((N - scale(2)) / 2), floor((M - scale(3)) / 2)];
                CNN.draw_cube(scale, center_translate, face_colors(i, :), face_alpha);
                text(...
                    -x_text, (i - 0.5) * N, 0, ...
                    sprintf('%dx%dx%d', scale(3), scale(2), scale(1)), ...
                    'FontSize', font_size, ...
                    'FontWeight', font_weight, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle' ...
                );
                translate = translate + [0, N, 0];
            end

            axis('equal');
            axis('off');
            view(3);

            hold('off');
        end
        
        function obj = load(filename)
            obj = load(filename);
            obj = obj.(char(fieldnames(obj)));
        end
        
        function x = normalize(x)
            m = size(x, 1);
            n = size(x, 2);
            for i = 1:m
                for j = 1:n
                    max_ = max(abs(x(i, j, :)));
                    if max_ ~= 0
                        x(i, j, :) = x(i, j, :) / max_;
                    end
                end
            end
        end
        
        function matrix = flipn(matrix)
            %FLIPN flip on all dimensions
            for dim = 1:ndims(matrix)
                matrix = flip(matrix, dim);
            end
        end
    end
    
end
