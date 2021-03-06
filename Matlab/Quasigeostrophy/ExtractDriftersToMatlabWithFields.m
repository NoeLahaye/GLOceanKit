file = '/Volumes/OceanTransfer/AnisotropicExperiments/AnisotropicDataAdam/QGBetaPlaneTurbulenceFloats_experiment_05.nc';
output_file = '/Volumes/OceanTransfer/AnisotropicExperiments/AnisotropicDataAdam/QGBetaPlaneTurbulenceFloats_experiment_05_MoreParams.mat';

shouldSaveStrainAndVorticity = 0;

stride = 32;

%addpath('../GLOceanKit/Matlab/')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 	Read in the problem dimensions
%
xFloat = ncread(file, 'x-float');
yFloat = ncread(file, 'y-float');
t = ncread(file, 'time');

height_scale = ncreadatt(file, '/', 'height_scale');
time_scale = ncreadatt(file, '/', 'time_scale');
length_scale = ncreadatt(file, '/', 'length_scale');
vorticity_scale = ncreadatt(file, '/', 'vorticity_scale');
k_f = ncreadatt(file, '/', 'forcing_wavenumber');
k_f_width = ncreadatt(file, '/', 'forcing_width');
k_nu = ncreadatt(file, '/', 'viscous_wavenumber');
k_alpha = ncreadatt(file, '/', 'thermal_damping_wavenumber');
k_r = ncreadatt(file, '/', 'frictional_damping_wavenumber');
f_zeta = ncreadatt(file, '/', 'f_zeta');
latitude = ncreadatt(file, '/', 'latitude');
k_max = ncreadatt(file, '/', 'max_resolved_wavenumber');
uses_beta = ncreadatt(file, '/', 'uses-beta');
r = ncreadatt(file, '/', 'r')/time_scale;
nu = ncreadatt(file, '/', 'nu')*length_scale*length_scale/time_scale;

[u,v,F,zeta,ssh, sshFD, k, l, f0, length_scale] = FieldsFromTurbulenceFile(file,length(t),'u','v','force','rv', 'ssh', 'ssh_fd', 'k', 'l', 'f0', 'length_scale');
u_rms_eulerian = sqrt(mean(mean(u.^2+v.^2)));

% pick of peak of spectrum.
[kMag, TE, KE, PE, KEx, KEy] = EnergySpectrumFromSSH( sshFD, k, l, 9.81, f0, length_scale );
[~,index] = max(KE);
max_kinetic_energy_length = 1/kMag(index);
[~,index] = max(KEx);
max_kinetic_energy_u_length = 1/kMag(index);
[~,index] = max(KEy);
max_kinetic_energy_v_length = 1/kMag(index);



g = 9.81;
f0 = 2 * 7.2921E-5 * sin( latitude*pi/180. );
R = 6.371e6;
beta0 = double(uses_beta)*(2 * 7.2921E-5 * cos( latitude*pi/180. ) / R);

x = ncread(file, 'x');
y = ncread(file, 'y');

dt = t(2)-t(1);
dx = x(2)-x(1);
dy = y(2)-y(1);
Lx = dx*length(x);
Ly = dy*length(y);

eta = -sum(sum(F.*ssh))*dx*dy/(Lx*Ly);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 	The stride indicates how many floats we will skip
%

timestride = 1;
t_days = t/86400;
day = 11500;
timeIndex = find( t_days-1 <= day, 1, 'last');
% timeIndex = length(t);

xPosition = squeeze(ncread(file, 'x-position', [ceil(stride/2) ceil(stride/2) 1], [length(yFloat)/stride length(xFloat)/stride timeIndex], [stride stride 1]));
yPosition = squeeze(ncread(file, 'y-position', [ceil(stride/2) ceil(stride/2) 1], [length(yFloat)/stride length(xFloat)/stride timeIndex], [stride stride 1]));


return;

% Reshape to [time, float]
xpos = (reshape(xPosition, [length(yFloat)*length(xFloat)/(stride*stride), timeIndex]))';
ypos = (reshape(yPosition, [length(yFloat)*length(xFloat)/(stride*stride), timeIndex]))';

timeIndices = 1:timestride:timeIndex;

t = t(timeIndices);
xpos = xpos(timeIndices,:);
ypos = ypos(timeIndices,:);

cx = xpos + sqrt(-1)*ypos;
cv = vdiff(dt,cx,1);

[~, ~, q, r] = CenterOfMass( real(cx), imag(cx) );
x_model = q;
y_model = r;
[minD, maxD, theta_model] = SecondMomentMatrix( x_model, y_model, 'eigen' );

if shouldSaveStrainAndVorticity == 1
	
	% need a mesh grid for interp2, y proceeds x in these arrays.

	[X,Y]=meshgrid( x,y  );
	
	strain_s = zeros( size(xpos) );
	strain_n = zeros( size(xpos) );
	rv = zeros( size(xpos) );
	energy_force = zeros( size(xpos) );
	energy_drag = zeros( size(xpos) );
	enstrophy_force = zeros( size(xpos) );
	enstrophy_drag = zeros( size(xpos) );
    
	for iTime = 1:length(timeIndices)
        timeIndex = timeIndices(iTime);
        
        % Start with the (easy) second layer
        wrappedX2 = mod( xpos(iTime,:)-min(x), max(x)-min(x) ) + min(x);
		wrappedY2 = mod( ypos(iTime,:)-min(y), max(y)-min(y) ) + min(y);
        
        [strain_s_eul, strain_n_eul, rv_eul, psi_eul, force_eul] = FieldsFromTurbulenceFile( file, timeIndex, 'strain_s', 'strain_n', 'rv', 'psi', 'force');
        
		strain_s(iTime,:) = interp2( X, Y, strain_s_eul, wrappedX, wrappedY );
		strain_n(iTime,:) = interp2( X, Y, strain_n_eul, wrappedX, wrappedY );
		rv(iTime,:) = interp2( X, Y, rv_eul, wrappedX, wrappedY );
		energy_force(iTime,:) = interp2( X, Y, psi_eul.*force_eul, wrappedX, wrappedY );
		energy_drag(iTime,:) = interp2( X, Y, alpha*psi_eul.*psi_eul, wrappedX, wrappedY );
		enstrophy_force(iTime,:) = interp2( X, Y, -rv_eul.*force_eul, wrappedX, wrappedY );
		enstrophy_drag(iTime,:) = interp2( X, Y, -alpha*rv_eul.*psi_eul, wrappedX, wrappedY );
	end
	
	save(output_file, 't', 'cx','cv','k_f', 'k_nu', 'k_r', 'k_alpha', 'latitude', 'k_max', 'r', 'nu', 'f0', 'beta0', 'dx', 'file', 'u_rms_eulerian', 'eta', 'max_kinetic_energy_length', 'max_kinetic_energy_u_length', 'max_kinetic_energy_v_length', 'enstrophy_force', 'enstrophy_drag', 'energy_force', 'energy_drag', 'strain_s', 'strain_n', 'rv');
else
	save(output_file, 't', 'cx','cv','k_f', 'k_nu', 'k_r', 'k_alpha', 'latitude', 'k_max', 'r', 'nu', 'f0', 'beta0', 'dx', 'file', 'u_rms_eulerian', 'eta', 'max_kinetic_energy_length', 'max_kinetic_energy_u_length', 'max_kinetic_energy_v_length');
end

figure, plot(xpos, ypos)