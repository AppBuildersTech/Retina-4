function createfigure(Y1, X1, Y2)
%CREATEFIGURE(Y1, X1, Y2)
%  Y1:  vector of y data
%  X1:  vector of x data
%  Y2:  vector of y data

%  Auto-generated by MATLAB on 18-Jan-2017 19:53:12

% Create figure
figure1 = figure('NumberTitle','off','Name','Parameters',...
    'OuterPosition',[0 0 1 1]);

% Create axes
axes1 = axes('Parent',figure1);
hold(axes1,'on');

% Create plot
plot(Y1);

% Create plot
plot(X1,Y2,'MarkerSize',10,'Marker','*','LineWidth',2,'LineStyle','none');

% Create xlabel
xlabel('epoch');

% Create title
title('Ganglion');

% Create ylabel
ylabel('bias');

box(axes1,'on');
