function [ outs, weights, loss, stopInfo, inTop, LgradAll, limits ] = buildKA_basisC_mod( x, y, lab, identID, verifID, alp, Nrun, xmin, xmax, ymin, ymax, fnB0, fnT0, Options )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

arguments
    x (:,:) double
    y (:,1) double
    lab (:,1) double
    identID (1,1) double
    verifID (1,1) double
    alp (1,1) double
    Nrun (1,1) double
    xmin (1,1) double
    xmax (1,1) double
    ymin (1,1) double
    ymax (1,1) double
    fnB0 (:,:) double
    fnT0 (:,:) double
    Options.verifPatience (1,1) double = 10
    Options.lossTolerance (1,1) double = 0.001
end

% check
if not(any(lab == identID))
    error('You must have at least 1 observation leave for training!')
end

% validation parameters
verifPatience = Options.verifPatience;
lossTolerance = Options.lossTolerance;

%. num. of records
N = size(x,1);

%. num. of inputs
m = size(x,2);

%. limits
tmin = ymin;
tmax = ymax;

%. init. operators
fnB = fnB0;
fnT = fnT0;
n = size(fnB,1);
q = size(fnT,1);
p = size(fnT,2);

err_all = zeros(N,1);
t_all = zeros(N,p);
outs = zeros(N,1);
loss = array2table(zeros(Nrun,2), 'VariableNames',{'Train','Valid'});
inTop = array2table(repmat({zeros(Nrun,p)}, 2, 2), 'VariableNames',{'Train','Valid'}, 'RowNames',{'Min','Max'});
LgradAll = struct('Bottom',zeros(N,n*p*m), 'Top',zeros(N,q*p));

%. proj. matrix
Cpq = kron(eye(p),ones(q,1));

Mn = splineMatrix(n);
Mq = splineMatrix(q);

fnB_r = reshape(fnB,n*m,p);
fnT_r = fnT(:);

% train and valid inds
indsTrn = ( lab == identID );
indsVal = ( lab == verifID );

trStopID = 0; % ID to understand why training stopped

for jj=1:Nrun
    for ii=1:N
        %. calc.
        if ( lab(ii) == identID )||( lab(ii) == verifID )
            xx = x(ii,:);
            yy = y(ii);

            %. calc. bottom
            [ phi, dphi, ddphi ] = basisFunc_spline( xx, xmin, xmax, n, Mn );
            t = phi(:).'*fnB_r;

            %. calc. top
            [ psi, dpsi, ddpsi, dddpsi ] = basisFunc_spline( t, tmin, tmax, q, Mq );
            yhat = psi(:).'*fnT_r;
            Lnum = yhat - yy;

            %. deriv.
            dpsiEx = diag(dpsi(:)) * Cpq;
            top = fnT_r.' * dpsiEx;
            der = phi(:) * top;
            LgradB = der(:).';
            LgradT = psi(:).';

            %. export
            err_all(ii) = abs(Lnum);
            t_all(ii,:) = t;
            outs(ii) = yhat;
            LgradAll.Bottom(ii,:) = LgradB;
            LgradAll.Top(ii,:) = LgradT;
        end
        
        %. ident.
        if ( lab(ii) == identID )
            chi = sum(LgradB.^2) + sum(LgradT.^2);
            fnB_r = fnB_r - alp * Lnum * reshape(LgradB,n*m,p)/chi;
            fnT_r = fnT_r - alp * Lnum * LgradT.'/chi;
        end
    end

    loss{jj,'Train'} = sqrt( sum( err_all(indsTrn).^2 )/sum(indsTrn) )/(ymax-ymin);
    inTop{'Min','Train'}{:}(jj,:) = min(t_all(indsTrn,:));
    inTop{'Max','Train'}{:}(jj,:) = max(t_all(indsTrn,:));

    if any(indsVal)
        loss{jj,'Valid'} = sqrt( sum( err_all(indsVal).^2 )/sum(indsVal) )/(ymax-ymin);
        inTop{'Min','Valid'}{:}(jj,:) = min(t_all(indsVal,:));
        inTop{'Max','Valid'}{:}(jj,:) = max(t_all(indsVal,:));

        if (jj >= 2) && (loss{jj-1,'Valid'} < loss{jj,'Valid'})
            incrValL = incrValL + 1; % number of increase in loss
        else
            incrValL = 0;
        end

        if incrValL >= verifPatience
            trStopID = 2;
            break
        end
    end

    if loss{jj,'Train'} <= lossTolerance
        trStopID = 3;
        break
    end

    % printProgr = 1;
    % if ( printProgr == 1 )
    %     if ( jj > 1 )
    %         fprintf( repmat( '\b', 1, 34 ) );
    %     end
    %     fprintf( '  pass %04.0f out of %04.0f completed\n', jj, Nrun );
    % end
end

if jj == Nrun
    trStopID = 1;
end

stopInfo.Iterations = jj;
stopInfo.TrainingLoss = loss{jj,'Train'};
stopInfo.ValidationLoss = loss{jj,'Valid'};
stopInfo.LossTolerance = lossTolerance;
stopInfo.ValidationChecks = verifPatience;
switch trStopID
    case 1
        stopInfo.ConvergenceCriterion = 'Training stopped at maximum epoch';

    case 2
        stopInfo.ConvergenceCriterion = 'Training stopped bacause the validation patience is reached';

    case 3
        stopInfo.ConvergenceCriterion = 'Training stopped bacause the loss is under the threshold';

    case 0
        stopInfo.ConvergenceCriterion = 'Training stopped bacause of unknown reason!';
end

fnB = reshape(fnB_r,n,p*m);
fnT = reshape(fnT_r,q,p);

weights = struct('Bottom',fnB, 'Top',fnT);

limits = struct('xmin',xmin, 'xmax',xmax, 'ymin',ymin, 'ymax',ymax);

end
