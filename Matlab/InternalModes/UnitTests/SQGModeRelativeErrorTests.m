methods = cell(1,1);
methods{1} = 'spectral';
methods{2} = 'wkbSpectral';
methods{3} = 'densitySpectral';
methods{4} = 'wkbAdaptiveSpectral';
methods{5} = 'finiteDifference';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize the analytical solution
n = 2*64;
latitude = 33;
[rhoFunction, N2Function, zIn] = InternalModes.StratificationProfileWithName('constant');
z = linspace(min(zIn),max(zIn),n)';
imAnalytical = InternalModesConstantStratification(rhoFunction,zIn,z,latitude,'nModes',n);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute a range of free surface modes
k = 10.^linspace(log10(1e-5),log10(1e-1),10)';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define the error function: y is the true solution, x is the approximated
errorFunction = @(x,y) max(abs(x-y),[],1)./max(abs(y),[],1);
errorTolerance = 1e-2;

for iMethod=1:length(methods)
    im = InternalModes(rhoFunction,zIn,z,latitude,'nModes',n, 'method', methods{iMethod});
    
    psi = im.SurfaceModesAtWavenumber( k );
    psi_analytical = imAnalytical.SurfaceModesAtWavenumber( k );
    max_error = max(errorFunction(psi,psi_analytical));
    fprintf('%s surface modes has an error of %g\n', methods{iMethod}, max_error);
    
    psi = im.BottomModesAtWavenumber( k );
    psi_analytical = imAnalytical.BottomModesAtWavenumber( k );
    max_error = max(errorFunction(psi,psi_analytical));
    fprintf('%s bottom modes has an error of %g\n', methods{iMethod}, max_error);
end
