function tests = test_pipeline
% Run with: runtests('tests')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'modules'));
tc.TestData.out = tempname; mkdir(tc.TestData.out);
end

function teardownOnce(tc)
if isfolder(tc.TestData.out), rmdir(tc.TestData.out,'s'); end
end

function testSyntheticValidation(tc)
p = vt_defaults();
r = vt_validate(tc.TestData.out, p);
verifyGreaterThan(tc, r.detectionPrecision, 0.9);
verifyGreaterThan(tc, r.detectionRecall, 0.9);
verifyGreaterThan(tc, r.trackIdentityConsistency, 0.8);
verifyGreaterThanOrEqual(tc, r.eventRecall, 0.6);
end

function testAssignmentFallback(tc)
C = [1 Inf; Inf 2];
pairs = sortrows(vt_assignment(C, 10, 'hungarian'));
verifyEqual(tc, pairs, [1 1; 2 2]);
end

function testROIFromJSON(tc)
q = jsondecode('{"roiPolygons":[[[0,0],[10,0],[10,10]],[[20,20],[30,20],[30,30]]]}');
p = vt_merge_params(vt_defaults(), q);
verifyClass(tc, p.roiPolygons, 'cell');
verifyNumElements(tc, p.roiPolygons, 2);
verifySize(tc, p.roiPolygons{1}, [3 2]);
end

function testUnknownSettingRejected(tc)
verifyError(tc, @() vt_merge_params(vt_defaults(), struct('notASetting',1)), ?MException);
end
