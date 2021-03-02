import { memo } from 'react';
import { connect } from 'react-redux';
import { compose } from 'redux';
import styled from 'styled-components';
import unknownFunction from 'somewhere';
import { hot } from 'react-hot-loader';

import { MyComponent } from './exportedComponent';

const StyledComponent = styled(MyComponent)`
    color: red;
`;

function mapStateToProps(x) {
    return x;
}
function mapDispatchToProps(x) {
    return x;
}

const withConnect = connect(mapStateToProps, mapDispatchToProps);

const ConnectedComponent = compose(withConnect, unknownFunction)(StyledComponent);

export default hot(module)(memo(ConnectedComponent));
