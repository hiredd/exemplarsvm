function [rec,prec,ap,apold,fp,tp,npos,is_correct] = ...
    VOCevaldet(test_set,BB,cls,params)

if ~exist('params','var')
  params.evaluation_minoverlap = 0.5;
  params.display = 1;
end

% % load test set
% tic
% cp=sprintf(VOCopts.annocachepath,VOCopts.testset);
% if exist(cp,'file')
%   if ~exist('recs','var')
%     fprintf('%s: pr: loading ground truth\n',cls);
    
%     load(cp,'gtids','recs');
%     %keyboard
%   end
% else
%     %[gtids,t]=textread(sprintf(VOCopts.imgsetpath,...
%     %                           VOCopts.testset),'%s %d');
%     [gtids,t] = textread(sprintf(VOCopts.clsimgsetpath, ...
%                                    cls,VOCopts.testset),'%s %d');
    
    
%     for i=1:length(gtids)
%         % display progress
%         if toc>1
%             fprintf('%s: pr: load: %d/%d\n',cls,i,length(gtids));
%             drawnow;
%             tic;
%         end
%         if t(i)~=-1
%           % read annotation
%           recs{i}=PASreadrecord(sprintf(VOCopts.annopath, ...
%                                         gtids{i}));
%         else
%           recs{i} = [];
%         end
%     end
%     save(cp,'gtids','recs');
% end

fprintf('%s: pr: evaluating detections\n',cls);

% if strcmp(VOCopts.dataset,'VOC2007')
%   for i = 1:length(gtids)
%     gtids{i} = ['2007_' gtids{i}];
%   end
% end
% hash image ids
%hash=VOChash_init(gtids);
        
% extract ground truth objects

npos=0;
gt(length(test_set))=struct('BB',[],'diff',[],'det',[]);
for i=1:length(test_set)
    % extract objects of class
    if numel(test_set{i})==0
      continue
    end

    if ~isfield(test_set{i},'objects') || ...
          length(test_set{i}.objects)==0
      %dont do anything if no objects, no gt!
    else
      clsinds=strmatch(cls,{test_set{i}.objects(:).class},'exact');
      gt(i).BB=cat(1,test_set{i}.objects(clsinds).bbox)';
      gt(i).diff=[test_set{i}.objects(clsinds).difficult];
      gt(i).det=false(length(clsinds),1);
      %skip difficult ones in evaluation
      npos=npos+sum(~gt(i).diff);
    end

end

% if isfield(VOCopts,'filename')
%   filename = VOCopts.filename;
% else
%   filename = sprintf(VOCopts.detrespath,id,cls);
% end

% % % load results
% [ids,confidence,b1,b2,b3,b4]=textread(filename,'%s %f %f %f %f %f');
% BB=[b1 b2 b3 b4]';

%BB = stuff{1}.BB;
%ids = stuff{1}.ids;
%confidence = stuff{1}.conf;

% if strcmp(VOCopts.dataset,'VOC2007')
%   for i = 1:length(ids)
%     ids{i} = ['2007_' ids{i}];
%   end
% end

sss = tic;
[ap, apold, rec, prec, fp, tp, is_correct] = get_aps(params,cls,gt,npos,BB);

finaltime = toc(sss);
fprintf(1,'Time for computing AP: %.3fsec\n',finaltime);

function [ap,apold,rec,prec,fp,tp,is_correct] = get_aps(params,cls,gt,npos,BB);

[~,order] = sort(BB(:,end),'descend');
BB = BB(order,:);
%confidence = con
% sort detections by decreasing confidence
%[sc,si]=sort(-confidence);
%ids=ids(si);
%BB=BB(:,si);


confidence = BB(:,end);

% assign detections to ground truth objects
nd=length(confidence);
tp=zeros(nd,1);
fp=zeros(nd,1);

tic;

%do instead of slow hash
%[~,iii] = ismember(ids,gtids);

is_correct = zeros(nd,1);
for d=1:nd
    % display progress
    % if toc>1
    %     fprintf('%s: pr: compute: %d/%d\n',cls,d,nd);
    %     drawnow;
    %     tic;
    % end
    
    % find ground truth image
    %i=VOChash_lookup(hash,ids{d});
    % i = iii(d);
    % if isempty(i)
    %     error('unrecognized image "%s"',ids{d});
    % elseif length(i)>1
    %     error('multiple image "%s"',ids{d});
    % end

    % assign detection to ground truth object if any
    bb = BB(d,1:4);
    i = BB(d,11);
    %bb=BB(:,d);
    ovmax=-inf;

    try
    for j=1:size(gt(i).BB,2)
        bbgt=gt(i).BB(:,j);
        bi=[max(bb(1),bbgt(1)) ; max(bb(2),bbgt(2)) ; min(bb(3),bbgt(3)) ; min(bb(4),bbgt(4))];
        iw=bi(3)-bi(1)+1;
        ih=bi(4)-bi(2)+1;
        if iw>0 & ih>0                
            % compute overlap as area of intersection / area of union
            ua=(bb(3)-bb(1)+1)*(bb(4)-bb(2)+1)+...
               (bbgt(3)-bbgt(1)+1)*(bbgt(4)-bbgt(2)+1)-...
               iw*ih;
            ov=iw*ih/ua;
            if ov>ovmax
                ovmax=ov;
                jmax=j;
            end
        end
    end
    catch
      keyboard
    end
    % assign detection as true positive/don't care/false positive
    if ovmax>=params.evaluation_minoverlap
        if ~gt(i).diff(jmax)
            if ~gt(i).det(jmax)
                tp(d)=1;            % true positive
		gt(i).det(jmax)=true;
                is_correct(d) = 1;
            else
                fp(d)=1;            % false positive (multiple detection)
            end
        end
    else
        fp(d)=1;                    % false positive
    end
end

% compute precision/recall
fp=cumsum(fp);
tp=cumsum(tp);
rec=tp/npos;
prec=tp./(fp+tp);

% compute average precision
ap=0;
for t=0:0.1:1
    p=max(prec(rec>=t));
    if isempty(p)
        p=0;
    end
    ap=ap+p/11;
end

apold = ap;
ap = VOCap(rec,prec);

if params.display
    % plot precision/recall
    plot(rec,prec,'-','LineWidth',2);
    grid;
    xlabel 'recall'
    ylabel 'precision'
    title(sprintf('class: %s, AP = %.3f, OS=%.3f',...
                  cls, ap, params.evaluation_minoverlap));
end
