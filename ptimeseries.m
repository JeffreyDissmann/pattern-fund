classdef ptimeseries
    %TIMESERIES Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        myData = table();
        frequency = ''; %daily or monthly or annual
        Name = '';
    end
    
    methods
        function this = ptimeseries(dates,myData,Name,frequency)
            this.Name = Name;
            this.frequency = frequency;
            
            if isa(myData,'table')
                this.myData = myData;
            else
                this.myData = table(myData);
            end
            
            %add dates
            dates = datenum(dates);
            datest = table(dates,datestr(dates,'yyyy-mm-dd'),'VariableNames',{'dates','date_string'});
            
            this.myData = [datest,this.myData];
            
            %sortby dates
            %newes = 1, oldes = end
            [~,I] = sort(dates);
            this.myData = this.myData(I,:);
        end
        
        function this = subsref(this,S)
            switch S(1).type
                case '()'
                    this.myData = subsref(this.myData,substruct('()',{S(1).subs{1},':'}));
                    if length(S) > 1
                        this = subsref(this,S(2:end));
                    end
                    return;
                case '{}'
                    builtin('subsref',this,S) %call builtin
                case '.'
                    if strcmpi(S(1).subs,'dates')
                        this = this.myData.dates;
                    elseif strcmpi(S(1).subs,'myData')
                        this = this.myData;
                    elseif any(strcmp(S(1).subs,methods(this))) %function call
                        this = builtin('subsref',this,S); %call builtin
                        return
                    else
                        this.myData = [this.myData(:,1:2),table(subsref(this.myData,S),'VariableName',{S.subs})];
                    end
                    return;
            end
        end
        
        function disp(this)
            disp(['Name: ',this.Name]);
            disp('');
            if size(this.myData,1) < 10
                disp(this.myData);
            else
                disp(this.myData(1:3,:));
                disp('   ...   ');
                disp(this.myData(end-2:end,:));
            end
        end
        
        function this = dateref(this,dates)
            dates = datenum(dates);
            ids = arrayfun(@(d) find(this.myData.dates==d,1),dates);
            
            this.myData = this.myData(ids,:);
        end
        
        function fn = fieldnames(this)
            fn = builtin('fieldnames',this);
            fn = cat(1,fn,fieldnames(this.myData));
        end
        
        function this = lag(this,l)
            %Shift all except dates
            this.myData(l+1:end,3:end) = this.myData(1:end-l,3:end);
            this.myData(1:l,3:end) = num2cell(nan(size(this.myData(1:l,3:end))));
        end
        
        function A = rdivide(A,B)
            %check if same dates
            if ~all(A.myData.dates == B.myData.dates)
                error('ptimeseries::rdivide dates not equal');
            end
            
            %dvide
            for i = 3:length(A.myData.Properties.VariableNames)
                A.myData.(A.myData.Properties.VariableNames{i}) = A.myData.(A.myData.Properties.VariableNames{i}) ./ B.myData.(A.myData.Properties.VariableNames{i});
            end
        end
        
        function A = minus(A,B)                
            for i = 3:length(A.myData.Properties.VariableNames)
                A.myData.(A.myData.Properties.VariableNames{i}) = A.myData.(A.myData.Properties.VariableNames{i}) - B;
            end
        end
        
        function this = chfield(this,old,new)
            this.myData.Properties.VariableNames{strcmp(this.myData.Properties.VariableNames,old)} = new;
        end
        
        function A = combineTS(A,B)
            %check if same dates
            if ~all(A.myData.dates == B.myData.dates)
                error('ptimeseries::combineTS dates not equal');
            end
            
            A.myData = [A.myData, B.myData(:,3:end)];
        end
        
        function this = reduceTodates(this,dates) 
            
            %Reduce to dates
            jDates = sort(intersect(dates,this.myData.dates));
            this = this.dateref(jDates);
            
            
            %Add missing rows
            missingdates = dates(arrayfun(@(d) ~any(d==this.myData.dates),dates));
            for md = missingdates'
                this.myData = [this.myData;this.myData(end,:)];
                this.myData.dates(end) = md;
                this.myData.date_string(end,:) = datestr(md,'yyyy-mm-dd');
                this.myData(end,3:end) = num2cell(nan(1,size(this.myData,2)-2));
                
            end
            
            %sortby dates
            %newes = 1, oldes = end
            [~,I] = sort(dates);
            this.myData = this.myData(I,:);
            
        end
        
        function n = length(this)
            n = size(this.myData,1);
        end
        
        function A = trailingFunCombineFinTS(A,B,fun,interval,name)
             %check if same dates
            if ~((length(A.myData.dates) == length(B.myData.dates)) && ...
                    all(A.myData.dates == B.myData.dates))
                error('ptimeseries::trailingFunCombineFinTS dates not equal');
            end
            
            %calculate statistic
            trailingTS = arrayfun(@(i) fun(...
                                            A.subsref(substruct('()',{(i:i+interval-1)})),...
                                            B.subsref(substruct('()',{(i:i+interval-1)}))),...
                                            1:length(A)-interval )';

%             %form ts
%             trailingTS = fints(ts1.dates(interval:end), trailingTS, {name}, ts1.freq);

        end
    end
    
end
