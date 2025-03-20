function unstProb = fs2probs(fsVal, Options)

arguments
    fsVal (:,:) double {mustBeVector}
    Options.fsLims (1,2) double = [.1, 10]
end

fsLims = Options.fsLims;

%% Check inputs
if fsLims(1) >= fsLims(2)
    error('1st member of fsLims must be < than 2nd member!')
end

if 1/fsLims(1) ~= fsLims(2)
    warning('Members of fsLims are not mutual!')
end

isSmlFs = fsVal < fsLims(1);
if any(isSmlFs)
    warning('The minimum of fsVal is < than fsLims(1). Values below fsLims(1) will be cut!')
    fsVal(isSmlFs) = fsLims(1);
end

isBigFs = fsVal > fsLims(2);
if any(isBigFs)
    warning('The maximum of fsVal is > than fsLims(2). Values above fsLims(2) will be cut!')
    fsVal(isBigFs) = fsLims(2);
end

isNanFs = isnan(fsVal);
if any(isNanFs)
    warning(['fsVal contains some nans. These nans are supposed to be ', ...
             'unconditionally stable points and will be replaced by fsLims(2)!'])
    fsVal(isNanFs) = fsLims(2);
end

%% Core
dltLgLms = log10(fsLims(2)) - log10(fsLims(1));
unstProb = 1 - ( log10(fsVal)-log10(fsLims(1)) ) / dltLgLms;

end