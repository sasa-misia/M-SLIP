function CrssEntr = crossentropy2(Predictions, Targets)

% This is a simple function to evaluate crossentropy because the original
% one has a conflict (same function name in 2 different toolbox)
%
% Syntax
%
%     CrssEntr = crossentropy2(Predictions, Targets)

CrssEntr = sum(Targets.*log(Predictions))/numel(Predictions);

end