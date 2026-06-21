%Script to segment MRtrix .tck files into segments based on centroid
%coordinates. Output = .tck file per segment, .tck for centroid, .tsf file
%for colouring centroid, and .tsf file for colouring original .tck input
%file

clear;
Tracts_dir='/PATH/TO/DIRECTORY/template/segmentations';
cd(Tracts_dir);
% Tracts=ls(Tracts_dir);
Tracts = dir('*_*');

ref_coords=[-70,-50,-50];
centroid_indices=[1,20;21,40;41,60];


for tt=2:size(Tracts,1); %For each tract

    %Load track file
    % Tractname=Tracts(tt,:);
    %Tractname=Tractname(find(~isspace(Tractname)));
    % Tract=read_mrtrix_tracks([Tractname, '.tck']);
    Tractname = dir([Tracts_dir,'/',Tracts(tt).name,'/*tck']);
    Tractname = [Tracts_dir,'/',Tracts(tt).name,'/',Tractname.name(1:end-4)];
    Tract = read_mrtrix_tracks([Tractname,'.tck']);

    %Identify 1-3 largest centroids
    num_centroids=1;

    %Load in centroid data
    centroid=[];
    centroid_vertices={};
    centroid_colour={};

    for yy=0:num_centroids-1; %For each centroid
        centroid_add=load([Tracts_dir,'/',Tracts(tt).name, '/centroid-', num2str(yy), '.txt']); %Load centroid

        %Flip centroid so that all tract segments are oriented the same way (1 starts at posterior/inferior/left end of tract)
        dist_end1=sqrt(sum(bsxfun(@minus,centroid_add(1,:),ref_coords).^2,2));
        dist_end2=sqrt(sum(bsxfun(@minus,centroid_add(20,:),ref_coords).^2,2));
        %If the 20th point is closer to the reference coordinate, flip the centroid
        if dist_end1 < dist_end2;
            centroid_add=flipud(centroid_add);
        end

        %combine centroid's data into single variables
        centroid=[centroid;centroid_add];
        centroid_vertices{yy+1}=centroid_add;
        centroid_colour{yy+1}=[centroid_indices(yy+1,1):centroid_indices(yy+1,2)]';
    end

    %Processing performed on each streamline
    Indices={};
    Streamlines={};
    Streamline_colours={};
    for dd=1:length(Tract.data); %For each streamline
        points=Tract.data{dd};
        for ii=1:length(centroid);
            ref=centroid(ii,:);
            distances(:,ii)=sqrt(sum(bsxfun(@minus,points,ref).^2,2));
        end
        [minVal,minInd]=min(distances,[],2);
        Indices{1,dd}=minInd;
        for jj=1:num_centroids*20; %For each centroid segment
            index=find(minInd==jj)';
            if isempty(index)==0;
                grouped=mat2cell(index, 1, diff( [0, find(diff(index) ~= 1), length(index)]));
                for tt=1:length(grouped); %for each streamline vertices that belong to a given segment
                    %grouped_points{tt}=points(grouped{tt},:);
                    group=points(grouped{tt},:);
                    group_color=ones(size(group,1),1)*jj;
                    Streamlines{jj,length(Streamlines)+1}=group;
                    Streamline_colours{jj,length(Streamline_colours)+1}=group_color;
                end
            end
            %Streamlines{jj,dd}=points(find(minInd==jj),:);
        end
        clear distances;
    end

    %Write TSF for main tract
    Tract_colour=Tract;
    Tract_colour.roi='roi.nii.gz'; %need to convert to a character string to write tck file
    Tract_colour.data=Indices; %Replace data with just one central streamline
    write_mrtrix_tsf(Tract_colour,[Tractname, '.tsf']);

    %Write Centroids TCK and TSF
    for gg=1:num_centroids;
        %Write Centroid TCK
        Tract_centroid=Tract_colour;
        Tract_centroid.data=centroid_vertices(gg);
        write_mrtrix_tracks(Tract_centroid,[Tractname, '_centroid-', num2str(gg), '.tck']);

        %Write Centroid TSF
        Tract_centroid_colour=read_mrtrix_tracks([Tractname, '_centroid-', num2str(gg), '.tck']);
        Tract_centroid_colour.data=centroid_colour(gg); %Replace data with just one central streamline with 20 segments
        write_mrtrix_tsf(Tract_centroid_colour,[Tractname, '_centroid-', num2str(gg), '.tsf']);

        %Write a TCK and TSF file of the tract divided into centroids
        Tract_segment=Tract_colour;
        Tract_centroid.data=centroid_vertices(gg);
        write_mrtrix_tracks(Tract_centroid,[Tractname, '_centroid-', num2str(gg), '.tck']);
    end

    %Write a single tck file with all centroids
    Tract_centroids=Tract_colour;
    Tract_centroids.data=centroid_vertices; %Replace data with centroid vertices, with one streamline per centroid
    write_mrtrix_tracks(Tract_centroids,[Tractname, '_centroids.tck']);

    %Write a single TSF file with all centroids
    Tract_centroids_colour=read_mrtrix_tracks([Tractname, '_centroids.tck']);
    Tract_centroids_colour.data=centroid_colour; %Replace data with just one central streamline with 20 segments
    write_mrtrix_tsf(Tract_centroids_colour,[Tractname, '_centroids.tsf']);


    %Write Tract Segments and Seperate tracts for each centroid
    Tract_divided=Tract_colour;
    Tract_divided_centroid1=Tract_colour; Tract_divided_centroid1.data={}; data_centroid1_colours={};
    Tract_divided_centroid2=Tract_colour; Tract_divided_centroid2.data={}; data_centroid2_colours={};
    Tract_divided_centroid3=Tract_colour; Tract_divided_centroid3.data={}; data_centroid3_colours={};
    for jj=1:num_centroids*20;
        data=Streamlines(jj,:);
        index=cellfun(@isempty,data) ==0;
        data=data(index);
        data_colour=Streamline_colours(jj,:); data_colour=data_colour(index);
        if 0<jj && jj<21 ;

            Tract_divided_centroid1.data=[Tract_divided_centroid1.data(1:end),data];
            data_centroid1_colours=[data_centroid1_colours(1:end),data_colour];
        elseif 20<jj && jj<41;
            Tract_divided_centroid2.data=[Tract_divided_centroid2.data(1:end),data];
            data_centroid2_colours=[data_centroid2_colours(1:end),data_colour];
        elseif 40<jj && jj<61;
            Tract_divided_centroid3.data=[Tract_divided_centroid3.data(1:end),data];
            data_centroid3_colours=[data_centroid3_colours(1:end),data_colour];
        end
        Tract_divided.data=data;
        filename=[Tractname, '_', num2str(jj), '.tck'];
        write_mrtrix_tracks(Tract_divided,filename)
    end

    %Write tck and tsf file for each centroid segment
    %First segment
    write_mrtrix_tracks(Tract_divided_centroid1,[Tractname, '_segment1.tck']);
    Tract_divided_centroid1_colours=read_mrtrix_tracks([Tractname, '_segment1.tck']);
    Tract_divided_centroid1_colours.data=data_centroid1_colours;
    write_mrtrix_tsf(Tract_divided_centroid1_colours,[Tractname, '_segment1.tsf']);
    %Second segment
    if num_centroids > 1;
        write_mrtrix_tracks(Tract_divided_centroid2,[Tractname, '_segment2.tck']);
        Tract_divided_centroid2_colours=read_mrtrix_tracks([Tractname, '_segment2.tck']);
        Tract_divided_centroid2_colours.data=data_centroid2_colours;
        write_mrtrix_tsf(Tract_divided_centroid2_colours,[Tractname, '_segment2.tsf']);
    end
    if num_centroids > 2;
        write_mrtrix_tracks(Tract_divided_centroid3,[Tractname, '_segment3.tck']);
        Tract_divided_centroid3_colours=read_mrtrix_tracks([Tractname, '_segment3.tck']);
        Tract_divided_centroid3_colours.data=data_centroid3_colours;
        write_mrtrix_tsf(Tract_divided_centroid3_colours,[Tractname, '_segment3.tsf']);
    end
end
