function [data, w] = dyn_normalize_data(data, K, w, scale, res_pri, res_dual, D_old, E_old, iter)
%if (iter > 1000)
%    return
%end

global scale_err_i
%EPS = 1 / iter;
EPS = 0.25;
Kp = 0.1 / iter;
Ki = 0;

if (0 && norm(res_dual) > 10 * norm(res_pri) || norm(res_dual) < norm(res_pri) / 10)
    scale_err = 1 - norm(res_dual)/norm(res_pri);
    scale_err_i = scale_err_i + scale_err;
    p_val = Kp * scale_err;
    i_val = Ki * scale_err_i;
    %d_val = self.Kd * (err - self.err_last)
    %self.err_last = err
    w.scale = min(max(scale + (p_val + i_val), 1e-5), 1e2);
else
    scale_err_i = 0;
    w.scale = scale;
end

[m,n] = size(data.A);

p = 1 ./(abs(res_pri)  + 0.001);
d = 1 ./(abs(res_dual) + 0.001);

p = p./mean(p,1);
d = d./mean(d,1);

MIN_SCALE = 1e-3;
MAX_SCALE = 1e3;
minRowScale = MIN_SCALE * sqrt(n);
maxRowScale = MAX_SCALE * sqrt(n);
minColScale = MIN_SCALE * sqrt(m);
maxColScale = MAX_SCALE * sqrt(m);

%% D scale:
Dt = p(1:K.f+K.l);
idx = K.f + K.l;
for i=1:length(K.q)
    if (K.q(i) > 0)
        nmA = mean(p(idx+1:idx+K.q(i)));
        Dt = [Dt;nmA*ones(K.q(i),1)];
        idx = idx + K.q(i);
    end
end
for i=1:length(K.s)
    if (K.s(i) > 0)
        nmA = mean(p(idx+1:idx+getSdConeSize(K.s(i))));
        Dt = [Dt;nmA*ones(getSdConeSize(K.s(i)),1)];
        idx = idx + getSdConeSize(K.s(i));
    end
end
for i=1:K.ep
    nmA = mean(p(idx+1:idx+3));
    Dt = [Dt;nmA*ones(3,1)];
    idx = idx + 3;
end
for i=1:K.ed
    nmA = mean(p(idx+1:idx+3));
    Dt = [Dt;nmA*ones(3,1)];
    idx = idx + 3;
end
for i=1:length(K.p)
    nmA = mean(p(idx+1:idx+3,:));
    Dt = [Dt;nmA*ones(3,1)];
    idx = idx + 3;
end

Dt(Dt < minRowScale) = minRowScale;
Dt(Dt > maxRowScale) = maxRowScale;
if (~isnan(D_old))
    Dt = (1-EPS)*D_old + EPS*Dt;
end
data.A = sparse(diag(1./Dt))*data.A_orig;

%% E Scale
Et = d;
Et(Et < minColScale) = minColScale;
Et(Et > maxColScale) = maxColScale;
if (~isnan(E_old))
    Et = (1-EPS)*E_old + EPS*Et;
end
data.A = data.A*sparse(diag(1./Et));

nmrowA = 1;%mean(twonorms(data.A'));
nmcolA = 1;%mean(twonorms(data.A));

data.A = data.A*scale;

data.b = data.b_orig./Dt;
sc_b = 1;%nmcolA/ max(norm(data.b), MIN_SCALE);
data.b = data.b * sc_b * scale;

data.c = data.c_orig./Et;
sc_c = 1;%nmrowA/max(norm(data.c), MIN_SCALE);
data.c = data.c * sc_c * scale;

w.D = Dt;
w.E = Et;
w.sc_b = sc_b;
w.sc_c = sc_c;

    function twoNorms = twonorms(A)
        twoNorms = sqrt(sum(A.^2,1));
    end

end